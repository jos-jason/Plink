import SwiftUI

struct PinCardView: View {
    @Bindable var pin: Pin
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image area — variable height creates the masonry effect
            if let imagePath = pin.imagePath {
                AsyncCachedImage(filename: imagePath)
                    .aspectRatio(
                        pin.imageAspectRatio,
                        contentMode: .fit
                    )
                    .frame(maxWidth: .infinity)
                    .clipped()
            } else if !pin.metadataFetched {
                // Loading placeholder
                Rectangle()
                    .fill(.quaternary)
                    .aspectRatio(1.5, contentMode: .fit)
                    .overlay {
                        ProgressView()
                    }
            }

            // Text area
            VStack(alignment: .leading, spacing: 4) {
                if !pin.title.isEmpty {
                    Text(pin.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .foregroundStyle(.primary)
                }
                if !pin.domain.isEmpty {
                    Text(pin.domain)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(AppConstants.cardPadding)
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardCornerRadius))
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
        .task {
            guard !pin.metadataFetched else { return }
            await fetchMetadata()
        }
    }

    private func fetchMetadata() async {
        guard let url = pin.url else {
            pin.metadataFetched = true
            return
        }

        do {
            let metadata = try await MetadataService.shared.fetchMetadata(for: url)

            if pin.title.isEmpty {
                pin.title = metadata.title
            }
            if pin.pageDescription.isEmpty {
                pin.pageDescription = metadata.description
            }
            if pin.domain.isEmpty {
                pin.domain = metadata.domain
            }

            if let imageData = metadata.imageData, !pin.isCustomImage {
                let filename = try ImageStorageService.saveImage(
                    imageData, for: pin.id
                )
                pin.imagePath = filename
                pin.imageAspectRatio = ImageStorageService.aspectRatio(from: imageData)
            }

            pin.metadataFetched = true
            pin.dateModified = Date()
        } catch {
            // Mark as fetched even on failure to avoid retry loops
            pin.metadataFetched = true
        }
    }
}
