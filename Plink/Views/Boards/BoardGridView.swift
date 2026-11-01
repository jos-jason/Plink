import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct BoardGridView: View {
    @Query(sort: \Board.sortOrder) private var boards: [Board]
    @State private var showingNewBoard = false
    @State private var boardToRename: Board?
    @State private var draggingBoard: Board?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var columnCount: Int {
        #if os(macOS)
        return AppConstants.defaultColumnsMac
        #else
        switch horizontalSizeClass {
        case .regular:
            return AppConstants.defaultColumnsRegular
        default:
            return AppConstants.defaultColumnsCompact
        }
        #endif
    }

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
                    MasonryLayout(columns: columnCount) {
                        ForEach(boards) { board in
                            NavigationLink(value: board) {
                                BoardCardView(board: board)
                                    .opacity(draggingBoard?.id == board.id ? 0.4 : 1.0)
                                    .scaleEffect(draggingBoard?.id == board.id ? 0.95 : 1.0)
                            }
                            .buttonStyle(.plain)
                            .draggable(board.id.uuidString) {
                                // Drag preview
                                BoardCardView(board: board)
                                    .frame(width: 150)
                                    .onAppear { draggingBoard = board }
                            }
                            .onDrop(of: [.text], delegate: BoardDropDelegate(
                                targetBoard: board,
                                boards: boards,
                                draggingBoard: $draggingBoard,
                                reorder: reorderBoard
                            ))
                            .contextMenu {
                                Button {
                                    boardToRename = board
                                } label: {
                                    Label("Edit", systemImage: "pencil")
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

    private func reorderBoard(from draggedID: UUID, to targetBoard: Board) {
        let fromIndex = boards.firstIndex(where: { $0.id == draggedID })
        let toIndex = boards.firstIndex(where: { $0.id == targetBoard.id })
        guard let from = fromIndex, let to = toIndex, from != to else { return }

        var ordered = Array(boards)
        let moved = ordered.remove(at: from)
        ordered.insert(moved, at: to)

        for (index, board) in ordered.enumerated() {
            board.sortOrder = index
        }
    }
}

struct BoardCardView: View {
    let board: Board

    /// The aspect ratio from the cover pin's image, for dynamic card height
    private var coverAspectRatio: Double {
        guard let coverPin = board.pins
            .sorted(by: { $0.dateAdded > $1.dateAdded })
            .first(where: { $0.imagePath != nil })
        else { return 1.3 }
        return coverPin.imageAspectRatio
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Cover image — uses the pin's aspect ratio for dynamic height
            if let coverPath = board.coverImagePath {
                AsyncCachedImage(filename: coverPath)
                    .aspectRatio(coverAspectRatio, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipped()
            } else {
                Rectangle()
                    .fill(.quaternary)
                    .aspectRatio(1.3, contentMode: .fit)
                    .overlay {
                        Image(systemName: board.icon)
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

struct BoardDropDelegate: DropDelegate {
    let targetBoard: Board
    let boards: [Board]
    @Binding var draggingBoard: Board?
    let reorder: (UUID, Board) -> Void

    func performDrop(info: DropInfo) -> Bool {
        draggingBoard = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        // Reorder live as the user drags over each card
        guard let dragging = draggingBoard,
              dragging.id != targetBoard.id else { return }
        reorder(dragging.id, targetBoard)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func validateDrop(info: DropInfo) -> Bool {
        draggingBoard != nil
    }

    func dropExited(info: DropInfo) {}
}
