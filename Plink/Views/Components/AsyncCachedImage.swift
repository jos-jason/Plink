import SwiftUI

struct AsyncCachedImage: View {
    let filename: String

    var body: some View {
        let url = ImageStorageService.imageURL(for: filename)
        if let data = try? Data(contentsOf: url) {
            #if canImport(UIKit)
            if let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                imagePlaceholder
            }
            #else
            if let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                imagePlaceholder
            }
            #endif
        } else {
            imagePlaceholder
        }
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
