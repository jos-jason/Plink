import SwiftUI
import SwiftData

struct BoardGridView: View {
    @Query(sort: \Board.sortOrder) private var boards: [Board]
    @State private var showingNewBoard = false
    @State private var boardToRename: Board?

    private let gridColumns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
    ]

    var body: some View {
        Group {
            if boards.isEmpty {
                EmptyStateView(
                    title: "No Boards",
                    subtitle: "Organize your pins into boards.",
                    systemImage: "folder",
                    actionTitle: "Create Board",
                    action: { showingNewBoard = true }
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: gridColumns, spacing: 16) {
                        ForEach(boards) { board in
                            NavigationLink(value: board) {
                                BoardCardView(board: board)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button {
                                    boardToRename = board
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    deleteBoard(board)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Boards")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingNewBoard = true
                } label: {
                    Label("New Board", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingNewBoard) {
            BoardEditorView()
        }
        .sheet(item: $boardToRename) { board in
            BoardEditorView(board: board)
        }
    }

    @Environment(\.modelContext) private var modelContext

    private func deleteBoard(_ board: Board) {
        modelContext.delete(board)
    }
}

struct BoardCardView: View {
    let board: Board

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Cover image
            if let coverPath = board.coverImagePath {
                AsyncCachedImage(filename: coverPath)
                    .aspectRatio(1.2, contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .clipped()
            } else {
                Rectangle()
                    .fill(.quaternary)
                    .frame(height: 120)
                    .overlay {
                        Image(systemName: "folder")
                            .font(.largeTitle)
                            .foregroundStyle(.tertiary)
                    }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(board.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Text("\(board.pins.count) pin\(board.pins.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(AppConstants.cardPadding)
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardCornerRadius))
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
    }
}
