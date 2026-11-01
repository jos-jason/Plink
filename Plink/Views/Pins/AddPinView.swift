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

    // Preview / image selection state
    @State private var isFetchingPreview = false
    @State private var fetchedMetadata: PinMetadata?
    @State private var availableImageURLs: [URL] = []
    @State private var selectedImageIndex: Int?
    @State private var lastFetchedURL = ""
    @State private var debounceTask: Task<Void, Never>?

    init(board: Board? = nil) {
        self.board = board
    }

    private var hasPreview: Bool {
        fetchedMetadata != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                // URL entry
                Section {
                    HStack {
                        TextField("https://example.com", text: $urlText)
                            .focused($urlFieldFocused)
                            #if !os(macOS)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            #endif
                            .autocorrectionDisabled()
                            .onSubmit(fetchPreview)
                            .disabled(isFetchingPreview)

                        if isFetchingPreview {
                            ProgressView()
                        }
                    }
                } header: {
                    Text("URL")
                } footer: {
                    if !hasPreview && !isFetchingPreview {
                        Text("Paste or type a web link. A preview will load automatically.")
                    }
                }

                // Preview section (shown after fetching)
                if let metadata = fetchedMetadata {
                    if !metadata.title.isEmpty {
                        Section("Preview") {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(metadata.title)
                                    .font(.headline)
                                Text(metadata.domain)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // Image selection
                    if !availableImageURLs.isEmpty {
                        Section {
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 10) {
                                    ForEach(
                                        Array(availableImageURLs.enumerated()),
                                        id: \.offset
                                    ) { index, imageURL in
                                        ImageOptionView(
                                            url: imageURL,
                                            isSelected: selectedImageIndex == index
                                        )
                                        .onTapGesture {
                                            if selectedImageIndex == index {
                                                selectedImageIndex = nil
                                            } else {
                                                selectedImageIndex = index
                                            }
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .listRowInsets(EdgeInsets(
                                top: 8, leading: 4, bottom: 8, trailing: 4
                            ))
                        } header: {
                            Text("Choose an Image (\(availableImageURLs.count) found)")
                        } footer: {
                            Text("Tap to select, tap again to deselect. If none is selected, the default image will be used.")
                        }
                    }
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
                    Button("Save") { savePin() }
                        .disabled(
                            urlText.trimmingCharacters(
                                in: .whitespacesAndNewlines
                            ).isEmpty || isFetchingPreview
                        )
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
            .onChange(of: urlText) { _, newValue in
                autoFetchPreview(for: newValue)
            }
        }
    }

    private func autoFetchPreview(for text: String) {
        debounceTask?.cancel()

        let normalized = text.normalizedURLString
        guard normalized.isValidURL, normalized != lastFetchedURL else { return }

        // If the text looks like it was pasted (already a full URL), fetch immediately
        // Otherwise debounce to avoid fetching on every keystroke
        let delay: UInt64 = text.contains("://") ? 200_000_000 : 800_000_000

        debounceTask = Task {
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled else { return }
            fetchPreview()
        }
    }

    private func fetchPreview() {
        let normalized = urlText.normalizedURLString
        guard normalized.isValidURL, let url = URL(string: normalized) else { return }
        guard normalized != lastFetchedURL else { return }

        lastFetchedURL = normalized
        isFetchingPreview = true
        Task {
            do {
                let metadata = try await MetadataService.shared.fetchMetadata(for: url)
                fetchedMetadata = metadata
                availableImageURLs = metadata.availableImageURLs
                selectedImageIndex = nil
            } catch {
                // Preview failed — user can still save without preview
                fetchedMetadata = PinMetadata(
                    title: "", description: "",
                    domain: url.displayDomain,
                    imageData: nil, availableImageURLs: [],
                    faviconData: nil
                )
            }
            isFetchingPreview = false
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
        if let metadata = fetchedMetadata {
            pin.title = metadata.title
            pin.pageDescription = metadata.description
            pin.domain = metadata.domain
        }

        if let board {
            pin.boards = [board]
        }

        // If user selected an image, download and save it
        if let selectedIndex = selectedImageIndex,
           selectedIndex < availableImageURLs.count {
            let imageURL = availableImageURLs[selectedIndex]
            modelContext.insert(pin)

            // Download the selected image asynchronously
            Task {
                do {
                    let data = try await MetadataService.shared.downloadImage(from: imageURL)
                    let filename = try ImageStorageService.saveImage(data, for: pin.id)
                    pin.imagePath = filename
                    pin.imageAspectRatio = ImageStorageService.aspectRatio(from: data)
                    pin.isCustomImage = true
                    pin.metadataFetched = true
                    pin.dateModified = Date()
                } catch {
                    // Download failed — metadata fetch in PinCardView will try the default
                }
            }
        } else if let metadata = fetchedMetadata, let imageData = metadata.imageData {
            // No selection but we have the default OG image — use it
            do {
                let filename = try ImageStorageService.saveImage(imageData, for: pin.id)
                pin.imagePath = filename
                pin.imageAspectRatio = ImageStorageService.aspectRatio(from: imageData)
                pin.metadataFetched = true
            } catch {}
            modelContext.insert(pin)
        } else {
            // No preview fetched — just save; PinCardView will fetch metadata later
            modelContext.insert(pin)
        }

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

// MARK: - Image Option Thumbnail

struct ImageOptionView: View {
    let url: URL
    let isSelected: Bool

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 100, height: 100)
                    .clipped()
            case .failure:
                Rectangle()
                    .fill(.quaternary)
                    .frame(width: 100, height: 100)
                    .overlay {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.tertiary)
                    }
            case .empty:
                Rectangle()
                    .fill(.quaternary)
                    .frame(width: 100, height: 100)
                    .overlay { ProgressView() }
            @unknown default:
                EmptyView()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 3)
        )
        .overlay(alignment: .topTrailing) {
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.white, Color.accentColor)
                    .padding(4)
            }
        }
        .shadow(
            color: isSelected ? Color.accentColor.opacity(0.3) : .clear,
            radius: 4
        )
    }
}
