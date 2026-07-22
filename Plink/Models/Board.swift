import Foundation
import SwiftData

@Model
final class Board {
    var id: UUID
    var name: String
    var dateCreated: Date
    var dateModified: Date
    var sortOrder: Int

    @Relationship(inverse: \Pin.boards)
    var pins: [Pin]

    init(
        name: String,
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.name = name
        self.dateCreated = Date()
        self.dateModified = Date()
        self.sortOrder = sortOrder
        self.pins = []
    }

    /// Cover image: the image from the most recently added pin
    var coverImagePath: String? {
        pins
            .sorted { $0.dateAdded > $1.dateAdded }
            .first(where: { $0.imagePath != nil })?
            .imagePath
    }
}
