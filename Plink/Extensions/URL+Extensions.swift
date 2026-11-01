import Foundation

extension URL {
    /// Extracts the display domain (e.g., "apple.com" from "https://www.apple.com/path")
    nonisolated var displayDomain: String {
        guard let host = self.host(percentEncoded: false) else { return "" }
        // Strip "www." prefix for cleaner display
        if host.hasPrefix("www.") {
            return String(host.dropFirst(4))
        }
        return host
    }
}

extension String {
    /// Whether the string is a plausible URL
    nonisolated var isValidURL: Bool {
        guard let url = URL(string: self) else { return false }
        return url.scheme == "http" || url.scheme == "https"
    }

    /// Normalizes a user-entered string into a proper URL string
    /// by adding "https://" if no scheme is present.
    nonisolated var normalizedURLString: String {
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return trimmed
        }
        return "https://\(trimmed)"
    }
}
