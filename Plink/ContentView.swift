//
//  ContentView.swift
//  Plink
//
//  Created by JJ vollum on 7/21/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.modelContext) private var modelContext
    @AppStorage("faviconCleanupDone") private var faviconCleanupDone = false

    var body: some View {
        Group {
            #if os(macOS)
            BoardsNavigationView()
            #else
            if horizontalSizeClass == .compact {
                AppTabView()
            } else {
                BoardsNavigationView()
            }
            #endif
        }
        .task {
            if !faviconCleanupDone {
                cleanInvalidFavicons()
                faviconCleanupDone = true
            }
        }
    }

    /// One-time cleanup: removes invalid favicon files and resets affected pins to re-fetch.
    private func cleanInvalidFavicons() {
        _ = ImageStorageService.cleanInvalidFavicons()

        guard let pins = try? modelContext.fetch(FetchDescriptor<Pin>()) else { return }
        for pin in pins {
            // Reset pins that have no image and no favicon so favicons get fetched
            if pin.imagePath == nil && pin.faviconPath == nil {
                pin.metadataFetched = false
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Pin.self, Board.self], inMemory: true)
}
