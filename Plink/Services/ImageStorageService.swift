import Foundation
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

enum ImageStorageService {
    /// Directory where pin images are stored (in the App Group container
    /// so both the main app and share extension can access them)
    static var imageDirectory: URL {
        let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppConstants.appGroupIdentifier
        ) ?? FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return container.appendingPathComponent(
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

    /// The old image directory (Application Support) before the App Group migration
    private static var legacyImageDirectory: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return appSupport.appendingPathComponent(
            AppConstants.imageDirectoryName,
            isDirectory: true
        )
    }

    /// Removes favicon files that contain invalid data (e.g. HTML error pages).
    /// Returns the filenames that were removed so callers can clear the corresponding model paths.
    static func cleanInvalidFavicons() -> [String] {
        let directory = imageDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else {
            return []
        }
        var removed: [String] = []
        for file in files where file.contains("-favicon") {
            let fileURL = directory.appendingPathComponent(file)
            guard let data = try? Data(contentsOf: fileURL) else { continue }
            #if canImport(UIKit)
            let isValid = UIImage(data: data) != nil
            #else
            let isValid = NSImage(data: data) != nil
            #endif
            if !isValid {
                try? FileManager.default.removeItem(at: fileURL)
                removed.append(file)
            }
        }
        return removed
    }

    /// Migrates images from the old Application Support location to the App Group container.
    /// Safe to call multiple times — skips if already done or if there's nothing to migrate.
    static func migrateImagesIfNeeded() {
        let fm = FileManager.default
        let oldDir = legacyImageDirectory
        let newDir = imageDirectory

        guard fm.fileExists(atPath: oldDir.path) else { return }

        // Create destination if needed
        try? fm.createDirectory(at: newDir, withIntermediateDirectories: true)

        guard let files = try? fm.contentsOfDirectory(atPath: oldDir.path) else { return }

        for file in files {
            let oldFile = oldDir.appendingPathComponent(file)
            let newFile = newDir.appendingPathComponent(file)

            // Only move if it doesn't already exist at the destination
            if !fm.fileExists(atPath: newFile.path) {
                try? fm.moveItem(at: oldFile, to: newFile)
            }
        }

        // Clean up old directory if empty
        if let remaining = try? fm.contentsOfDirectory(atPath: oldDir.path), remaining.isEmpty {
            try? fm.removeItem(at: oldDir)
        }
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
