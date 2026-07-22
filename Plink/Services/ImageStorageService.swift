import Foundation
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

enum ImageStorageService {
    /// Directory where pin images are stored
    static var imageDirectory: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return appSupport.appendingPathComponent(
            AppConstants.imageDirectoryName,
            isDirectory: true
        )
    }

    /// Saves image data to disk, returning the filename
    static func saveImage(_ data: Data, for pinID: UUID) throws -> String {
        let directory = imageDirectory
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let filename = "\(pinID.uuidString).jpg"
        let fileURL = directory.appendingPathComponent(filename)

        #if canImport(UIKit)
        if let image = UIImage(data: data),
           let jpegData = image.jpegData(
            compressionQuality: AppConstants.imageCompressionQuality
           ) {
            try jpegData.write(to: fileURL)
        } else {
            try data.write(to: fileURL)
        }
        #else
        if let image = NSImage(data: data),
           let tiffData = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData),
           let jpegData = bitmap.representation(
            using: .jpeg,
            properties: [.compressionFactor: AppConstants.imageCompressionQuality]
           ) {
            try jpegData.write(to: fileURL)
        } else {
            try data.write(to: fileURL)
        }
        #endif

        return filename
    }

    /// Returns the full URL for a stored image filename
    static func imageURL(for filename: String) -> URL {
        imageDirectory.appendingPathComponent(filename)
    }

    /// Deletes the image file for a pin
    static func deleteImage(filename: String) {
        let fileURL = imageDirectory.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// Returns the aspect ratio (width/height) of an image from its data
    static func aspectRatio(from data: Data) -> Double {
        #if canImport(UIKit)
        guard let image = UIImage(data: data) else { return 1.5 }
        let size = image.size
        #else
        guard let image = NSImage(data: data) else { return 1.5 }
        let size = image.size
        #endif
        guard size.height > 0 else { return 1.5 }
        return Double(size.width / size.height)
    }
}
