import Foundation
import SwiftData

@Model
final class Pin {
    var id: UUID
    var urlString: String
    var title: String
    var pageDescription: String
    var domain: String
    var dateAdded: Date
    var dateModified: Date

    /// Relative filename for the stored image within PinImages/
    var imagePath: String?

    /// Relative filename for the stored favicon within PinImages/
    var faviconPath: String?

    /// Whether the user manually chose/uploaded this image
    var isCustomImage: Bool

    /// Whether metadata has been fetched (distinguishes "no metadata" from "not yet attempted")
    var metadataFetched: Bool

    /// Many-to-many: a pin can belong to multiple boards
    var boards: [Board]

    var notes: String

    /// Aspect ratio of the stored image (width / height), used for layout sizing
    var imageAspectRatio: Double

    /// User-defined sort order within a view
    var sortOrder: Int

    init(
        urlString: String,
        title: String = "",
        pageDescription: String = "",
        domain: String = "",
        imagePath: String? = nil,
        isCustomImage: Bool = false,
        metadataFetched: Bool = false,
        boards: [Board] = [],
        notes: String = "",
        imageAspectRatio: Double = 1.5,
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.urlString = urlString
        self.title = title
        self.pageDescription = pageDescription
        self.domain = domain
        self.dateAdded = Date()
        self.dateModified = Date()
        self.imagePath = imagePath
        self.isCustomImage = isCustomImage
        self.metadataFetched = metadataFetched
        self.boards = boards
        self.notes = notes
        self.imageAspectRatio = imageAspectRatio
        self.sortOrder = sortOrder
    }

    var url: URL? {
        URL(string: urlString)
    }
}
