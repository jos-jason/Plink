import SwiftUI
import SwiftData

struct AddPinView: View {
    let board: Board?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var urlText = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    @FocusState private var urlFieldFocused: Bool

    init(board: Board? = nil) {
        self.board = board
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("https://example.com", text: $urlText)
                        .focused($urlFieldFocused)
                        #if !os(macOS)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()
                        .onSubmit(savePin)
                } header: {
                    Text("URL")
                } footer: {
                    Text("Paste or type a web link. Metadata will be fetched automatically.")
                }

                if let board {
                    Section {
                        Label(board.name, systemImage: "folder")
                    } header: {
                        Text("Board")
                    }
                }
            }
            .navigationTitle("Add Link")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: savePin)
                        .disabled(urlText.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ).isEmpty)
                }
            }
            .alert("Invalid URL", isPresented: $showingError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                urlFieldFocused = true
                pasteFromClipboard()
            }
        }
    }

    private func savePin() {
        let normalized = urlText.normalizedURLString
        guard normalized.isValidURL else {
            errorMessage = "Please enter a valid web URL."
            showingError = true
            return
        }

        let pin = Pin(urlString: normalized)
        if let url = URL(string: normalized) {
            pin.domain = url.displayDomain
        }

        if let board {
            pin.boards = [board]
        }

        modelContext.insert(pin)
        dismiss()
    }

    private func pasteFromClipboard() {
        #if canImport(UIKit)
        if let clipboardString = UIPasteboard.general.string,
           clipboardString.normalizedURLString.isValidURL,
           urlText.isEmpty {
            urlText = clipboardString
        }
        #else
        if let clipboardString = NSPasteboard.general.string(forType: .string),
           clipboardString.normalizedURLString.isValidURL,
           urlText.isEmpty {
            urlText = clipboardString
        }
        #endif
    }
}
