import Foundation
import LinkPresentation
import UniformTypeIdentifiers

struct PinMetadata: Sendable {
    let title: String
    let description: String
    let domain: String
    let imageData: Data?
    /// All image URLs found on the page (OG images, large <img> tags, etc.)
    let availableImageURLs: [URL]
    /// Favicon image data (used as fallback when no OG image is available)
    let faviconData: Data?
}

actor MetadataService {
    static let shared = MetadataService()

    /// Fetches metadata including all available images from a page.
    func fetchMetadata(for url: URL) async throws -> PinMetadata {
        let provider = LPMetadataProvider()
        let metadata = try await provider.startFetchingMetadata(for: url)

        let title = metadata.title ?? ""
        let domain = url.displayDomain

        // Extract the primary OG image (only from imageProvider, not iconProvider)
        var imageData: Data?
        if let imageProvider = metadata.imageProvider {
            imageData = try? await loadImageData(from: imageProvider)
        }

        // Scrape all image URLs from the page HTML
        let availableImageURLs = await fetchPageImageURLs(from: url)

        // Fetch favicon: try LPMetadataProvider's iconProvider first, then HTML parsing
        var faviconData: Data?
        if let iconProvider = metadata.iconProvider {
            faviconData = try? await loadImageData(from: iconProvider)
        }
        if faviconData == nil {
            faviconData = await fetchFavicon(for: url)
        }

        return PinMetadata(
            title: title,
            description: "",
            domain: domain,
            imageData: imageData,
            availableImageURLs: availableImageURLs,
            faviconData: faviconData
        )
    }

    /// Downloads image data from a remote URL.
    /// Returns nil if the response is not an image (e.g. HTML error pages).
    func downloadImage(from url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)
        // Reject non-image responses (HTML error/redirect pages)
        if let httpResponse = response as? HTTPURLResponse,
           let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type"),
           contentType.hasPrefix("text/") {
            return Data()
        }
        // Also check the data header for HTML signatures
        if Self.isHTMLData(data) {
            return Data()
        }
        return data
    }

    // MARK: - Private

    private func loadImageData(from provider: NSItemProvider) async throws -> Data? {
        guard provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) else {
            return nil
        }
        return try await withCheckedThrowingContinuation { continuation in
            provider.loadDataRepresentation(
                forTypeIdentifier: UTType.image.identifier
            ) { data, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: data)
                }
            }
        }
    }

    /// Fetches the page HTML and extracts image URLs from <meta> OG tags and <img> tags.
    private func fetchPageImageURLs(from pageURL: URL) async -> [URL] {
        do {
            let (data, _) = try await URLSession.shared.data(from: pageURL)
            guard let html = String(data: data, encoding: .utf8) else { return [] }
            return parseImageURLs(from: html, baseURL: pageURL)
        } catch {
            return []
        }
    }

    /// Parses image URLs from HTML content using simple pattern matching.
    nonisolated private func parseImageURLs(from html: String, baseURL: URL) -> [URL] {
        var urls: [URL] = []
        var seen = Set<String>()

        // Extract og:image and twitter:image meta tags
        let metaPattern = #"<meta[^>]*(?:property|name)\s*=\s*["'](?:og:image|twitter:image)["'][^>]*content\s*=\s*["']([^"']+)["']"#
        let metaPatternAlt = #"<meta[^>]*content\s*=\s*["']([^"']+)["'][^>]*(?:property|name)\s*=\s*["'](?:og:image|twitter:image)["']"#

        for pattern in [metaPattern, metaPatternAlt] {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
                for match in matches {
                    if let range = Range(match.range(at: 1), in: html) {
                        let src = String(html[range])
                        if let url = resolveURL(src, base: baseURL), seen.insert(url.absoluteString).inserted {
                            urls.append(url)
                        }
                    }
                }
            }
        }

        // Extract <img> src attributes
        let imgPattern = #"<img[^>]*\bsrc\s*=\s*["']([^"']+)["']"#
        if let regex = try? NSRegularExpression(pattern: imgPattern, options: .caseInsensitive) {
            let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
            for match in matches {
                if let range = Range(match.range(at: 1), in: html) {
                    let src = String(html[range])
                    // Skip tiny images (icons, tracking pixels, data URIs, SVGs)
                    if src.hasPrefix("data:") || src.hasSuffix(".svg") { continue }
                    if let url = resolveURL(src, base: baseURL), seen.insert(url.absoluteString).inserted {
                        urls.append(url)
                    }
                }
            }
        }

        // Limit to a reasonable number
        return Array(urls.prefix(20))
    }

    /// Fetches the favicon for a URL, trying <link rel="icon"> tags first, then /favicon.ico.
    private func fetchFavicon(for pageURL: URL) async -> Data? {
        // Try to find a high-quality favicon from the page HTML
        if let faviconURL = await extractFaviconURL(from: pageURL) {
            if let data = try? await downloadImage(from: faviconURL), !data.isEmpty {
                return data
            }
        }

        // Fall back to the standard /favicon.ico path
        guard let scheme = pageURL.scheme, let host = pageURL.host() else { return nil }
        let faviconURL = URL(string: "\(scheme)://\(host)/favicon.ico")
        guard let url = faviconURL else { return nil }

        if let data = try? await downloadImage(from: url), !data.isEmpty {
            return data
        }

        return nil
    }

    /// Extracts the best favicon URL from the page's <link> tags.
    private func extractFaviconURL(from pageURL: URL) async -> URL? {
        do {
            let (data, _) = try await URLSession.shared.data(from: pageURL)
            guard let html = String(data: data, encoding: .utf8) else { return nil }
            return parseFaviconURL(from: html, baseURL: pageURL)
        } catch {
            return nil
        }
    }

    /// Parses favicon URLs from <link rel="icon"> and <link rel="apple-touch-icon"> tags.
    /// Prefers apple-touch-icon (larger) over standard icon.
    nonisolated private func parseFaviconURL(from html: String, baseURL: URL) -> URL? {
        var bestURL: URL?
        var bestSize = 0

        // Match <link> tags with rel containing "icon"
        let pattern = #"<link[^>]*\brel\s*=\s*["']([^"']*icon[^"']*)["'][^>]*\bhref\s*=\s*["']([^"']+)["'][^>]*>"#
        let patternAlt = #"<link[^>]*\bhref\s*=\s*["']([^"']+)["'][^>]*\brel\s*=\s*["']([^"']*icon[^"']*)["'][^>]*>"#

        // Pattern 1: rel before href
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
            for match in matches {
                if let relRange = Range(match.range(at: 1), in: html),
                   let hrefRange = Range(match.range(at: 2), in: html) {
                    let rel = String(html[relRange])
                    let href = String(html[hrefRange])
                    let size = rel.contains("apple-touch") ? 180 : 32
                    if size > bestSize, let url = resolveURL(href, base: baseURL) {
                        bestURL = url
                        bestSize = size
                    }
                }
            }
        }

        // Pattern 2: href before rel
        if let regex = try? NSRegularExpression(pattern: patternAlt, options: .caseInsensitive) {
            let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
            for match in matches {
                if let hrefRange = Range(match.range(at: 1), in: html),
                   let relRange = Range(match.range(at: 2), in: html) {
                    let rel = String(html[relRange])
                    let href = String(html[hrefRange])
                    let size = rel.contains("apple-touch") ? 180 : 32
                    if size > bestSize, let url = resolveURL(href, base: baseURL) {
                        bestURL = url
                        bestSize = size
                    }
                }
            }
        }

        return bestURL
    }

    /// Resolves a potentially relative URL against a base URL.
    nonisolated private func resolveURL(_ src: String, base: URL) -> URL? {
        if let absolute = URL(string: src), absolute.scheme != nil {
            return absolute
        }
        return URL(string: src, relativeTo: base)?.absoluteURL
    }
}

extension MetadataService {
    /// Checks if the data starts with an HTML signature (e.g. `<!doctype` or `<html`).
    nonisolated static func isHTMLData(_ data: Data) -> Bool {
        guard data.count >= 5 else { return false }
        let header = data.prefix(15)
        guard let str = String(data: header, encoding: .utf8)?.lowercased() else { return false }
        return str.hasPrefix("<!doc") || str.hasPrefix("<html") || str.hasPrefix("<head")
    }
}
