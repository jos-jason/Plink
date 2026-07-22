import SwiftUI
import PhotosUI

struct PinDetailView: View {
    @Bindable var pin: Pin
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @State private var showingDeleteConfirmation = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showingBoardPicker = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Image
                if let imagePath = pin.imagePath {
                    AsyncCachedImage(filename: imagePath)
                        .aspectRatio(pin.imageAspectRatio, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardCornerRadius))
                }

                // Title and domain
                VStack(alignment: .leading, spacing: 8) {
                    if !pin.title.isEmpty {
                        Text(pin.title)
                            .font(.title2)
                            .fontWeight(.bold)
                    }

                    if !pin.domain.isEmpty {
                        Label(pin.domain, systemImage: "globe")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if !pin.pageDescription.isEmpty {
                        Text(pin.pageDescription)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }

                // Open link button
                if let url = pin.url {
                    Button {
                        openURL(url)
                    } label: {
                        Label("Open Link", systemImage: "safari")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }

                Divider()

                // Notes
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes")
                        .font(.headline)
                    TextField(
                        "Add notes...",
                        text: $pin.notes,
                        axis: .vertical
                    )
                    .lineLimit(3...8)
                    .textFieldStyle(.roundedBorder)
                }

                // Boards
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Boards")
                            .font(.headline)
                        Spacer()
                        Button {
                            showingBoardPicker = true
                        } label: {
                            Label("Add to Board", systemImage: "plus.circle")
                                .font(.subheadline)
                        }
                    }

                    if pin.boards.isEmpty {
                        Text("Not in any boards")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    } else {
                        ForEach(pin.boards) { board in
                            HStack {
                                Label(board.name, systemImage: "folder")
                                Spacer()
                                Button {
                                    pin.boards.removeAll { $0.id == board.id }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.tertiary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                Divider()

                // Metadata
                VStack(alignment: .leading, spacing: 4) {
                    Text("Added \(pin.dateAdded.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text(pin.urlString)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
            }
            .padding()
        }
        .navigationTitle("Pin Details")
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    // Change image
                    PhotosPicker(
                        selection: $selectedPhotoItem,
                        matching: .images
                    ) {
                        Label("Change Image", systemImage: "photo")
                    }

                    // Refresh metadata
                    Button {
                        pin.metadataFetched = false
                    } label: {
                        Label("Refresh Metadata", systemImage: "arrow.clockwise")
                    }

                    // Copy link
                    Button {
                        copyLink()
                    } label: {
                        Label("Copy Link", systemImage: "doc.on.doc")
                    }

                    Divider()

                    // Delete
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete Pin", systemImage: "trash")
                    }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
        }
        .alert("Delete Pin?", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                deletePin()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove this pin.")
        }
        .sheet(isPresented: $showingBoardPicker) {
            BoardPickerView(pin: pin)
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                await loadCustomImage(from: newItem)
            }
        }
    }

    private func deletePin() {
        if let imagePath = pin.imagePath {
            ImageStorageService.deleteImage(filename: imagePath)
        }
        modelContext.delete(pin)
        dismiss()
    }

    private func copyLink() {
        #if canImport(UIKit)
        UIPasteboard.general.string = pin.urlString
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(pin.urlString, forType: .string)
        #endif
    }

    private func loadCustomImage(from item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }

        do {
            let filename = try ImageStorageService.saveImage(data, for: pin.id)
            pin.imagePath = filename
            pin.isCustomImage = true
            pin.imageAspectRatio = ImageStorageService.aspectRatio(from: data)
            pin.dateModified = Date()
        } catch {
            // Image save failed — ignore silently
        }
    }
}

/// Sheet for picking boards to add a pin to
struct BoardPickerView: View {
    @Bindable var pin: Pin
    @Query(sort: \Board.sortOrder) private var allBoards: [Board]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if allBoards.isEmpty {
                    Text("No boards yet. Create one first.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(allBoards) { board in
                        let isInBoard = pin.boards.contains { $0.id == board.id }
                        Button {
                            if isInBoard {
                                pin.boards.removeAll { $0.id == board.id }
                            } else {
                                pin.boards.append(board)
                            }
                        } label: {
                            HStack {
                                Label(board.name, systemImage: "folder")
                                Spacer()
                                if isInBoard {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                        .tint(.primary)
                    }
                }
            }
            .navigationTitle("Add to Board")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
