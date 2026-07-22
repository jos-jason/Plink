import Foundation
import LinkPresentation
import UniformTypeIdentifiers

struct PinMetadata: Sendable {
    let title: String
    let description: String
    let domain: String
    let imageData: Data?
}

actor MetadataService {
    static let shared = MetadataService()

    func fetchMetadata(for url: URL) async throws -> PinMetadata {
        let provider = LPMetadataProvider()
        let metadata = try await provider.startFetchingMetadata(for: url)

        let title = metadata.title ?? ""
        let domain = url.displayDomain

        // Extract image data from the OG image provider
        var imageData: Data?
        if let imageProvider = metadata.imageProvider {
            imageData = try? await loadImageData(from: imageProvider)
        }

        // Fallback: try the icon/favicon if no OG image was found
        if imageData == nil, let iconProvider = metadata.iconProvider {
            imageData = try? await loadImageData(from: iconProvider)
        }

        return PinMetadata(
            title: title,
            description: "",
            domain: domain,
            imageData: imageData
        )
    }

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
}
