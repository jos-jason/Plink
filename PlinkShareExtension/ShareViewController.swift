//
//  ShareViewController.swift
//  PlinkShareExtension
//
//  Created by JJ vollum on 7/21/26.
//

#if canImport(UIKit)
import UIKit
typealias PlatformImage = UIImage
#else
import AppKit
typealias PlatformImage = NSImage
#endif

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import LinkPresentation

// MARK: - View Controller (platform-specific)

#if canImport(UIKit)

@objc(ShareViewController)
class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        let attachments = (extensionContext?.inputItems.first as? NSExtensionItem)?.attachments ?? []

        let viewModel = SharePreviewViewModel()
        let shareView = ShareExtensionView(
            viewModel: viewModel,
            onSave: { [weak self] urlString, boardIDs in
                self?.savePin(urlString: urlString, boardIDs: boardIDs)
                self?.close()
            },
            onCancel: { [weak self] in
                self?.cancel()
            }
        )

        let tintedView = shareView.tint(Color("AccentColor"))
        let hostingController = UIHostingController(rootView: tintedView)
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        hostingController.didMove(toParent: self)

        loadData(viewModel: viewModel, attachments: attachments)
    }
}

#else

@objc(ShareViewController)
class ShareViewController: NSViewController {

    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 500))
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let attachments = (extensionContext?.inputItems.first as? NSExtensionItem)?.attachments ?? []

        let viewModel = SharePreviewViewModel()
        let shareView = ShareExtensionView(
            viewModel: viewModel,
            onSave: { [weak self] urlString, boardIDs in
                self?.savePin(urlString: urlString, boardIDs: boardIDs)
                self?.close()
            },
            onCancel: { [weak self] in
                self?.cancel()
            }
        )

        let tintedView = shareView.tint(Color("AccentColor"))
        let hostingController = NSHostingController(rootView: tintedView)
        addChild(hostingController)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hostingController.view)
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        loadData(viewModel: viewModel, attachments: attachments)
    }
}

#endif

// MARK: - Shared Logic (both platforms)

extension ShareViewController {

    func loadData(viewModel: SharePreviewViewModel, attachments: [NSItemProvider]) {
        Task {
            viewModel.loadBoards()

            for provider in attachments {
                if let url = await Self.extractURL(from: provider) {
                    viewModel.setURL(url)
                    break
                }
            }

            if viewModel.url == nil {
                viewModel.isLoading = false
            }
        }
    }

    static func extractURL(from provider: NSItemProvider) async -> URL? {
        for typeIdentifier in [UTType.url.identifier, UTType.plainText.identifier] {
            guard provider.hasItemConformingToTypeIdentifier(typeIdentifier) else { continue }
            do {
                let item = try await provider.loadItem(forTypeIdentifier: typeIdentifier)
                if let url = item as? URL { return url }
                if let url = item as? NSURL { return url as URL }
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    return url
                }
                if let text = item as? String,
                   let url = URL(string: text),
                   url.scheme?.hasPrefix("http") == true {
                    return url
                }
                // macOS sometimes wraps the URL in NSSecureCoding
                if let text = (item as? NSObject)?.description,
                   let url = URL(string: text),
                   url.scheme?.hasPrefix("http") == true {
                    return url
                }
            } catch {
                continue
            }
        }
        return nil
    }

    func savePin(urlString: String, boardIDs: Set<UUID>) {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.Babymechanical.Plink"
        ) else { return }

        let storeURL = containerURL.appendingPathComponent("Plink.store")
        do {
            let config = ModelConfiguration(url: storeURL)
            let container = try ModelContainer(
                for: Pin.self, Board.self,
                configurations: config
            )
            let context = ModelContext(container)

            let url = URL(string: urlString)
            let pin = Pin(
                urlString: urlString,
                domain: url?.host(percentEncoded: false) ?? ""
            )

            if !boardIDs.isEmpty {
                let descriptor = FetchDescriptor<Board>()
                if let allBoards = try? context.fetch(descriptor) {
                    pin.boards = allBoards.filter { boardIDs.contains($0.id) }
                }
            }

            context.insert(pin)
            try context.save()
        } catch {}
    }

    func close() {
        extensionContext?.completeRequest(returningItems: nil)
    }

    func cancel() {
        extensionContext?.cancelRequest(withError: CocoaError(.userCancelled))
    }
}

// MARK: - Preview ViewModel

struct BoardInfo: Identifiable {
    let id: UUID
    let name: String
    let icon: String
}

@MainActor
@Observable
class SharePreviewViewModel {
    var url: URL?
    var domain: String = ""
    var title: String = ""
    var previewImage: PlatformImage?
    var isLoading = true
    var isFetchingPreview = false
    var boards: [BoardInfo] = []
    var selectedBoardIDs: Set<UUID> = []

    init() {}

    /// Called once the URL has been extracted from the item provider
    func setURL(_ url: URL) {
        self.url = url
        self.domain = url.host(percentEncoded: false) ?? ""
        self.isLoading = false
        fetchPreview(for: url)
    }

    private func fetchPreview(for url: URL) {
        isFetchingPreview = true
        let provider = LPMetadataProvider()
        Task {
            do {
                let metadata = try await provider.startFetchingMetadata(for: url)
                self.title = metadata.title ?? ""

                if let imageProvider = metadata.imageProvider {
                    self.previewImage = await self.loadImage(from: imageProvider)
                }
                if self.previewImage == nil, let iconProvider = metadata.iconProvider {
                    self.previewImage = await self.loadImage(from: iconProvider)
                }
            } catch {}
            self.isFetchingPreview = false
        }
    }

    private func loadImage(from provider: NSItemProvider) async -> PlatformImage? {
        let typeID = UTType.image.identifier
        guard provider.hasItemConformingToTypeIdentifier(typeID) else { return nil }
        return await withCheckedContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: typeID) { data, _ in
                if let data, let image = PlatformImage(data: data) {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    func loadBoards() {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.Babymechanical.Plink"
        ) else { return }

        let storeURL = containerURL.appendingPathComponent("Plink.store")
        do {
            let config = ModelConfiguration(url: storeURL)
            let container = try ModelContainer(
                for: Pin.self, Board.self,
                configurations: config
            )
            let context = ModelContext(container)
            let descriptor = FetchDescriptor<Board>(sortBy: [SortDescriptor(\.sortOrder)])
            let fetchedBoards = try context.fetch(descriptor)
            self.boards = fetchedBoards.map { BoardInfo(id: $0.id, name: $0.name, icon: $0.icon) }
        } catch {}
    }
}

// MARK: - SwiftUI View for the Share Extension

struct ShareExtensionView: View {
    @Bindable var viewModel: SharePreviewViewModel
    let onSave: (String, Set<UUID>) -> Void
    let onCancel: () -> Void

    var body: some View {
        #if canImport(UIKit)
        iosBody
        #else
        macOSBody
        #endif
    }

    #if canImport(UIKit)
    private var iosBody: some View {
        NavigationStack {
            shareContent
                .navigationTitle("Save to Plink")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", action: onCancel)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            if let url = viewModel.url {
                                onSave(
                                    url.absoluteString,
                                    viewModel.selectedBoardIDs
                                )
                            }
                        }
                        .disabled(viewModel.url == nil)
                    }
                }
        }
    }
    #else
    private var macOSBody: some View {
        VStack(spacing: 0) {
            // Title bar with buttons
            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Text("Save to Plink")
                    .font(.headline)
                Spacer()
                Button("Save") {
                    if let url = viewModel.url {
                        onSave(
                            url.absoluteString,
                            viewModel.selectedBoardIDs
                        )
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(viewModel.url == nil)
            }
            .padding()

            Divider()

            shareContent
        }
        .frame(width: 400, height: 450)
    }
    #endif

    private var shareContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.url != nil {
                    // Link info card
                    VStack(alignment: .leading, spacing: 0) {
                        if let image = viewModel.previewImage {
                            previewImage(image)
                                .frame(maxWidth: .infinity, maxHeight: 180)
                                .clipped()
                        } else if viewModel.isFetchingPreview {
                            Rectangle()
                                .fill(.quaternary)
                                .frame(maxWidth: .infinity, minHeight: 120)
                                .overlay { ProgressView() }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            if !viewModel.title.isEmpty {
                                Text(viewModel.title)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .lineLimit(2)
                            }
                            Label(viewModel.domain, systemImage: "link")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                    }
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.1), radius: 6, y: 3)
                    .padding(.horizontal)
                } else if viewModel.isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Loading link...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No URL found")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }

                // Board picker
                if !viewModel.boards.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Save to Board")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)

                        let columns = [GridItem(.adaptive(minimum: 90), spacing: 10)]
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(viewModel.boards) { board in
                                boardChip(
                                    name: board.name,
                                    icon: board.icon,
                                    isSelected: viewModel.selectedBoardIDs.contains(board.id)
                                ) {
                                    if viewModel.selectedBoardIDs.contains(board.id) {
                                        viewModel.selectedBoardIDs.remove(board.id)
                                    } else {
                                        viewModel.selectedBoardIDs.insert(board.id)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.top, 20)
        }
    }

    private func previewImage(_ image: PlatformImage) -> some View {
        #if canImport(UIKit)
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
        #else
        Image(nsImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
        #endif
    }

    private func boardChip(
        name: String,
        icon: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                    .frame(height: 28)
                Text(name)
                    .font(.caption)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 72)
            .padding(.horizontal, 6)
            .padding(.vertical, 10)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.1))
            .foregroundStyle(isSelected ? Color.accentColor : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}
