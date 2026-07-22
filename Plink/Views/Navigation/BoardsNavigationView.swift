import SwiftUI
import SwiftData

struct BoardsNavigationView: View {
    @Query(sort: \Board.sortOrder) private var boards: [Board]
    @State private var selectedDestination: SidebarDestination? = .allPins
    @State private var showingNewBoard = false

    enum SidebarDestination: Hashable {
        case allPins
        case board(Board)
        case settings
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedDestination) {
                Section {
                    NavigationLink(value: SidebarDestination.allPins) {
                        Label("All Pins", systemImage: "pin")
                    }
                }

                Section("Boards") {
                    ForEach(boards) { board in
                        NavigationLink(value: SidebarDestination.board(board)) {
                            Label {
                                Text(board.name)
                            } icon: {
                                Image(systemName: "folder")
                            }
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                deleteBoard(board)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }

                    Button {
                        showingNewBoard = true
                    } label: {
                        Label("New Board", systemImage: "plus")
                            .foregroundStyle(.tint)
                    }
                }

                Section {
                    NavigationLink(value: SidebarDestination.settings) {
                        Label("Settings", systemImage: "gear")
                    }
                }
            }
            .navigationTitle("Plink")
            .sheet(isPresented: $showingNewBoard) {
                BoardEditorView()
            }
        } detail: {
            switch selectedDestination {
            case .allPins, .none:
                NavigationStack {
                    PinGridView()
                }
            case .board(let board):
                NavigationStack {
                    BoardDetailView(board: board)
                }
            case .settings:
                NavigationStack {
                    SettingsView()
                }
            }
        }
    }

    @Environment(\.modelContext) private var modelContext

    private func deleteBoard(_ board: Board) {
        modelContext.delete(board)
    }
}
