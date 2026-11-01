import SwiftUI

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

struct AsyncCachedImage: View {
    let filename: String
    var contentMode: ContentMode = .fill
    @State private var loadedImage: ImageWrapper?
    @State private var hasAttemptedLoad = false

    var body: some View {
        Group {
            if let loadedImage {
                loadedImage.image
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                imagePlaceholder
            }
        }
        .task(id: filename) {
            await loadImage()
        }
    }

    private func loadImage() async {
        let url = ImageStorageService.imageURL(for: filename)

        // Retry a few times if file isn't available yet
        // (share extension may have just written it)
        for attempt in 0..<5 {
            if attempt > 0 {
                try? await Task.sleep(nanoseconds: 300_000_000)
            }

            guard let data = try? Data(contentsOf: url) else { continue }

            #if canImport(UIKit)
            if let uiImage = UIImage(data: data) {
                loadedImage = ImageWrapper(image: Image(uiImage: uiImage))
                return
            }
            #else
            if let nsImage = NSImage(data: data) {
                loadedImage = ImageWrapper(image: Image(nsImage: nsImage))
                return
            }
            #endif
        }

        hasAttemptedLoad = true
    }

    private var imagePlaceholder: some View {
        Rectangle()
            .fill(.quaternary)
            .overlay {
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundStyle(.tertiary)
            }
    }
}

private struct ImageWrapper {
    let image: Image
}
