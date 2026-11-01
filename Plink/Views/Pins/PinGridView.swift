import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct PinGridView: View {
    let board: Board?

    @Query(sort: \Pin.dateAdded, order: .reverse) private var allPins: [Pin]
    @State private var visibleCount = AppConstants.paginationBatchSize
    @State private var showingAddPin = false
    @State private var searchText = ""
    @State private var pinForBoardPicker: Pin?
    @State private var draggingPin: Pin?
    @State private var isDragging = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL

    init(board: Board? = nil) {
        self.board = board
    }

    private var filteredPins: [Pin] {
        var pins: [Pin]
        if let board {
            pins = allPins
                .filter { $0.boards.contains(where: { $0.id == board.id }) }
                .sorted { $0.sortOrder < $1.sortOrder }
        } else {
            pins = allPins
        }

        if !searchText.isEmpty {
            pins = pins.filter { pin in
                pin.title.localizedCaseInsensitiveContains(searchText) ||
                pin.domain.localizedCaseInsensitiveContains(searchText) ||
                pin.urlString.localizedCaseInsensitiveContains(searchText) ||
                pin.notes.localizedCaseInsensitiveContains(searchText)
            }
        }

        return pins
    }

    /// Whether drag-to-reorder should be enabled (only inside a specific board, not "All Pins")
    private var reorderEnabled: Bool {
        board != nil && searchText.isEmpty
    }

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
            if filteredPins.isEmpty {
                if allPins.isEmpty && board == nil {
                    EmptyStateView(
                        title: "No Pins Yet",
                        subtitle: "Save links from the web to see them here.",
                        systemImage: "pin",
                        actionTitle: "Add a Link",
                        action: { showingAddPin = true }
                    )
                } else if !searchText.isEmpty {
                    EmptyStateView(
                        title: "No Results",
                        subtitle: "No pins match \"\(searchText)\".",
                        systemImage: "magnifyingglass"
                    )
                } else {
                    EmptyStateView(
                        title: "No Pins",
                        subtitle: "This board is empty.",
                        systemImage: "pin",
                        actionTitle: "Add a Link",
                        action: { showingAddPin = true }
                    )
                }
            } else {
                ScrollView {
                    let displayedPins = Array(filteredPins.prefix(visibleCount))
                    MasonryLayout(columns: columnCount) {
                        ForEach(displayedPins) { pin in
                            pinCardItem(pin: pin, displayedPins: displayedPins)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    if visibleCount < filteredPins.count {
                        ProgressView()
                            .padding()
                            .onAppear {
                                visibleCount += AppConstants.paginationBatchSize
                            }
                    }
                }
            }
        }
        .navigationTitle(board?.name ?? "All Pins")
        .navigationDestination(for: Pin.self) { pin in
            PinDetailView(pin: pin)
        }
        .searchable(text: $searchText, prompt: "Search pins")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddPin = true
                } label: {
                    Label("Add Pin", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddPin) {
            AddPinView(board: board)
        }
        .sheet(item: $pinForBoardPicker) { pin in
            BoardPickerView(pin: pin)
        }
    }

    @ViewBuilder
    private func pinCardItem(pin: Pin, displayedPins: [Pin]) -> some View {
        let card = NavigationLink(value: pin) {
            PinCardView(pin: pin)
                .opacity(isDragging && draggingPin?.id == pin.id ? 0.4 : 1.0)
                .scaleEffect(isDragging && draggingPin?.id == pin.id ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .contextMenu {
            pinContextMenu(for: pin)
        } preview: {
            PinCardView(pin: pin)
                .frame(width: 250)
        }

        if reorderEnabled {
            card
                .draggable(pin.id.uuidString) {
                    PinCardView(pin: pin)
                        .frame(width: 150)
                        .onAppear {
                            draggingPin = pin
                            isDragging = true
                        }
                }
                .onDrop(of: [.text], delegate: PinDropDelegate(
                    targetPin: pin,
                    pins: displayedPins,
                    draggingPin: $draggingPin,
                    isDragging: $isDragging,
                    reorder: reorderPin
                ))
        } else {
            card
        }
    }

    @ViewBuilder
    private func pinContextMenu(for pin: Pin) -> some View {
        // Open in browser
        if let url = pin.url {
            Button {
                openURL(url)
            } label: {
                Label("Open in Browser", systemImage: "safari")
            }
        }

        // Share
        if let url = pin.url {
            ShareLink(item: url) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }

        Divider()

        // Add to board
        Button {
            pinForBoardPicker = pin
        } label: {
            Label("Add to Board", systemImage: "folder.badge.plus")
        }

        // Copy link
        Button {
            #if canImport(UIKit)
            UIPasteboard.general.string = pin.urlString
            #else
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(pin.urlString, forType: .string)
            #endif
        } label: {
            Label("Copy Link", systemImage: "doc.on.doc")
        }

        Divider()

        // Delete
        Button(role: .destructive) {
            if let imagePath = pin.imagePath {
                ImageStorageService.deleteImage(filename: imagePath)
            }
            modelContext.delete(pin)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    private func reorderPin(from draggedID: UUID, to targetPin: Pin) {
        let pins = filteredPins
        guard let fromIndex = pins.firstIndex(where: { $0.id == draggedID }),
              let toIndex = pins.firstIndex(where: { $0.id == targetPin.id }),
              fromIndex != toIndex else { return }

        // Only update the sortOrder values that actually change
        var ordered = Array(pins)
        let moved = ordered.remove(at: fromIndex)
        ordered.insert(moved, at: toIndex)

        let range = min(fromIndex, toIndex)...max(fromIndex, toIndex)
        for index in range {
            if ordered[index].sortOrder != index {
                ordered[index].sortOrder = index
            }
        }
    }
}

struct PinDropDelegate: DropDelegate {
    let targetPin: Pin
    let pins: [Pin]
    @Binding var draggingPin: Pin?
    @Binding var isDragging: Bool
    let reorder: (UUID, Pin) -> Void

    func performDrop(info: DropInfo) -> Bool {
        draggingPin = nil
        isDragging = false
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let dragging = draggingPin,
              dragging.id != targetPin.id else { return }
        withAnimation(.default) {
            reorder(dragging.id, targetPin)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func validateDrop(info: DropInfo) -> Bool {
        draggingPin != nil
    }

    func dropExited(info: DropInfo) {}
}
