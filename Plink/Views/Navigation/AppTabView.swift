import SwiftUI

struct AppTabView: View {
    var body: some View {
        TabView {
            Tab("Pins", systemImage: "pin") {
                NavigationStack {
                    PinGridView()
                }
            }

            Tab("Boards", systemImage: "folder") {
                NavigationStack {
                    BoardGridView()
                        .navigationDestination(for: Board.self) { board in
                            BoardDetailView(board: board)
                        }
                }
            }

            Tab("Settings", systemImage: "gear") {
                NavigationStack {
                    SettingsView()
                }
            }
        }
    }
}
