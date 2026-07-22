import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

enum ExportService {
    static func exportJSON(pins: [Pin], boards: [Board]) throws -> Data {
        let boardExports = boards.map { board in
            BoardExport(
                id: board.id,
                name: board.name,
                dateCreated: board.dateCreated,
                sortOrder: board.sortOrder
            )
        }

        let pinExports = pins.map { pin in
            PinExport(
                id: pin.id,
                urlString: pin.urlString,
                title: pin.title,
                pageDescription: pin.pageDescription,
                domain: pin.domain,
                dateAdded: pin.dateAdded,
                dateModified: pin.dateModified,
                isCustomImage: pin.isCustomImage,
                notes: pin.notes,
                boardIDs: pin.boards.map(\.id)
            )
        }

        let export = PlinkExport(
            version: 1,
            exportDate: Date(),
            pins: pinExports,
            boards: boardExports
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(export)
    }

    static func importJSON(data: Data, into context: ModelContext) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let export = try decoder.decode(PlinkExport.self, from: data)

        // Create boards first
        var boardMap: [UUID: Board] = [:]
        for boardExport in export.boards {
            let board = Board(name: boardExport.name, sortOrder: boardExport.sortOrder)
            board.id = boardExport.id
            board.dateCreated = boardExport.dateCreated
            context.insert(board)
            boardMap[board.id] = board
        }

        // Create pins, linking to boards
        for pinExport in export.pins {
            let pin = Pin(
                urlString: pinExport.urlString,
                title: pinExport.title,
                pageDescription: pinExport.pageDescription,
                domain: pinExport.domain,
                notes: pinExport.notes
            )
            pin.id = pinExport.id
            pin.dateAdded = pinExport.dateAdded
            pin.dateModified = pinExport.dateModified
            pin.isCustomImage = pinExport.isCustomImage
            pin.boards = pinExport.boardIDs.compactMap { boardMap[$0] }
            context.insert(pin)
        }

        try context.save()
    }
}

/// Document type for file export
struct PlinkDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
