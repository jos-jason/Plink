//
//  PlinkApp.swift
//  Plink
//
//  Created by JJ vollum on 7/21/26.
//

import SwiftUI
import SwiftData

@main
struct PlinkApp: App {
    let modelContainer: ModelContainer

    init() {
        let schema = Schema([Pin.self, Board.self])

        let config: ModelConfiguration
        if let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppConstants.appGroupIdentifier
        ) {
            let storeURL = containerURL.appendingPathComponent("Plink.store")
            config = ModelConfiguration(schema: schema, url: storeURL)
        } else {
            // Fallback to default location if App Group is unavailable
            config = ModelConfiguration(schema: schema)
        }

        do {
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        // Migrate images from old Application Support location to App Group container
        ImageStorageService.migrateImagesIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
