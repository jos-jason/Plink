import SwiftUI
import SwiftData

struct BoardEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let existingBoard: Board?
    @State private var name: String
    @State private var icon: String
    @State private var iconSearchText = ""
    @FocusState private var nameFieldFocused: Bool

    private static let defaultIcons = [
        "folder", "star", "heart", "book", "camera",
        "music.note", "cart", "briefcase", "house",
        "gamecontroller", "airplane", "leaf", "paintbrush",
        "film", "globe", "lightbulb", "hammer", "wrench",
        "fork.knife", "cup.and.saucer", "tshirt", "shoe",
        "figure.run", "bicycle", "car", "graduationcap",
        "theatermasks", "trophy", "gift", "bookmark",
        "flag", "mappin", "tag", "bell", "sparkles"
    ]

    /// All SF Symbol names loaded from the system catalog
    private static let allSymbolNames: [String] = {
        guard let bundle = Bundle(identifier: "com.apple.CoreGlyphs"),
              let path = bundle.path(forResource: "name_availability", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let symbols = plist["symbols"] as? [String: String] else {
            return defaultIcons
        }
        return symbols.keys.sorted()
    }()

    private var displayedIcons: [String] {
        if iconSearchText.isEmpty {
            return Self.defaultIcons
        }
        let query = iconSearchText.lowercased()
        return Self.allSymbolNames.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    init(board: Board? = nil) {
        self.existingBoard = board
        self._name = State(initialValue: board?.name ?? "")
        self._icon = State(initialValue: board?.icon ?? "folder")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Board name", text: $name)
                        .focused($nameFieldFocused)
                }

                Section {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Search symbols...", text: $iconSearchText)
                            .autocorrectionDisabled()
                            #if !os(macOS)
                            .textInputAutocapitalization(.never)
                            #endif
                        if !iconSearchText.isEmpty {
                            Button {
                                iconSearchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if displayedIcons.isEmpty {
                        Text("No symbols match \"\(iconSearchText)\"")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 12) {
                            ForEach(displayedIcons.prefix(60), id: \.self) { symbol in
                                Button {
                                    icon = symbol
                                } label: {
                                    Image(systemName: symbol)
                                        .font(.title3)
                                        .frame(width: 40, height: 40)
                                        .background(
                                            icon == symbol
                                                ? Color.accentColor.opacity(0.2)
                                                : Color.clear
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(icon == symbol ? Color.accentColor : .clear, lineWidth: 2)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    HStack {
                        Text("Icon")
                        Spacer()
                        Label(icon, systemImage: icon)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(existingBoard == nil ? "New Board" : "Edit Board")
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
            existingBoard.icon = icon
            existingBoard.dateModified = Date()
        } else {
            let board = Board(name: trimmed, icon: icon)
            modelContext.insert(board)
        }
        dismiss()
    }
}
