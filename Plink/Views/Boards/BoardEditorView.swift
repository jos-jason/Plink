import SwiftUI
import SwiftData

struct BoardEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let existingBoard: Board?
    @State private var name: String
    @FocusState private var nameFieldFocused: Bool

    init(board: Board? = nil) {
        self.existingBoard = board
        self._name = State(initialValue: board?.name ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Board name", text: $name)
                        .focused($nameFieldFocused)
                }
            }
            .navigationTitle(existingBoard == nil ? "New Board" : "Rename Board")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ).isEmpty)
                }
            }
            .onAppear {
                nameFieldFocused = true
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let existingBoard {
            existingBoard.name = trimmed
            existingBoard.dateModified = Date()
        } else {
            let board = Board(name: trimmed)
            modelContext.insert(board)
        }
        dismiss()
    }
}
