// Duplicated model definitions for the Share Extension target.
// These must stay in sync with Plink/Models/Pin.swift and Board.swift.
// Both targets share the same SwiftData store via App Groups.

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
    var imagePath: String?
    var isCustomImage: Bool
    var metadataFetched: Bool
    var boards: [Board]
    var notes: String
    var imageAspectRatio: Double

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
        imageAspectRatio: Double = 1.5
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
    }
}

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
}
