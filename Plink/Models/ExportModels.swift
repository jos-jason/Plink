import Foundation

struct PinExport: Codable {
    let id: UUID
    let urlString: String
    let title: String
    let pageDescription: String
    let domain: String
    let dateAdded: Date
    let dateModified: Date
    let isCustomImage: Bool
    let notes: String
    let boardIDs: [UUID]
}

struct BoardExport: Codable {
    let id: UUID
    let name: String
    let dateCreated: Date
    let sortOrder: Int
}

struct PlinkExport: Codable {
    let version: Int
    let exportDate: Date
    let pins: [PinExport]
    let boards: [BoardExport]
}
