import SwiftUI
import SwiftData

struct PinGridView: View {
    let board: Board?

    @Query(sort: \Pin.dateAdded, order: .reverse) private var allPins: [Pin]
    @State private var visibleCount = AppConstants.paginationBatchSize
    @State private var showingAddPin = false
    @State private var searchText = ""
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    init(board: Board? = nil) {
        self.board = board
    }

    private var filteredPins: [Pin] {
        var pins: [Pin]
        if let board {
            pins = allPins.filter { $0.boards.contains(where: { $0.id == board.id }) }
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
                            NavigationLink(value: pin) {
                                PinCardView(pin: pin)
                            }
                            .buttonStyle(.plain)
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
    }
}
