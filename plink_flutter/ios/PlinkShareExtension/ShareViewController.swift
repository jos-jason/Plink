//
//  ShareViewController.swift
//  PlinkShareExtension
//
//  "Save to Plink" from any app's share sheet. The Flutter app keeps a
//  snapshot of its boards in the shared App Group container; this extension
//  shows them, and saves each shared link as a small JSON file in an inbox
//  folder there. The app imports the inbox when it opens or comes back to
//  the foreground (lib/data/share_inbox.dart).
//

import LinkPresentation
import SwiftUI
import UIKit
import UniformTypeIdentifiers

private let appGroup = "group.Babymechanical.Plink"
private let plinkAmber = Color(red: 0.847, green: 0.541, blue: 0.102)

/// Where the app and this extension exchange files.
enum ShareStore {
    static var folder: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent("share", isDirectory: true)
    }

    static func loadBoards() -> [BoardInfo] {
        guard let url = folder?.appendingPathComponent("boards.json"),
              let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(BoardSnapshot.self, from: data)
        else { return [] }
        return snapshot.boards
    }

    /// Writes one inbox file per share, so saves never overwrite each other
    /// or race with the app's import.
    static func save(_ item: SharedItem) throws {
        guard let inbox = folder?.appendingPathComponent("inbox", isDirectory: true) else {
            throw CocoaError(.fileNoSuchFile)
        }
        try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(item)
        let file = inbox.appendingPathComponent("\(UUID().uuidString).json")
        try data.write(to: file, options: .atomic)
    }
}

struct BoardSnapshot: Decodable {
    let boards: [BoardInfo]
}

struct BoardInfo: Decodable, Identifiable {
    let id: String
    let name: String
    /// An SF Symbol name chosen by the app to match the board's icon.
    let symbol: String
}

struct SharedItem: Encodable {
    let url: String
    let title: String
    let boardIds: [String]
    let sharedAt: Int64
}

// MARK: - View Controller

@objc(ShareViewController)
class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        let attachments = (extensionContext?.inputItems as? [NSExtensionItem] ?? [])
            .flatMap { $0.attachments ?? [] }

        let viewModel = SharePreviewViewModel()
        let shareView = ShareExtensionView(
            viewModel: viewModel,
            onSave: { [weak self] in self?.save(viewModel) },
            onCancel: { [weak self] in
                self?.extensionContext?.cancelRequest(withError: CocoaError(.userCancelled))
            }
        )
        .tint(plinkAmber)

        let host = UIHostingController(rootView: shareView)
        addChild(host)
        view.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        host.didMove(toParent: self)

        Task { @MainActor in
            viewModel.boards = ShareStore.loadBoards()
            for provider in attachments {
                if let url = await Self.extractURL(from: provider) {
                    viewModel.setURL(url)
                    break
                }
            }
            if viewModel.url == nil { viewModel.isLoading = false }
        }
    }

    private func save(_ viewModel: SharePreviewViewModel) {
        guard let url = viewModel.url else { return }
        do {
            try ShareStore.save(SharedItem(
                url: url.absoluteString,
                title: viewModel.title,
                boardIds: Array(viewModel.selectedBoardIDs),
                sharedAt: Int64(Date().timeIntervalSince1970 * 1000)
            ))
            extensionContext?.completeRequest(returningItems: nil)
        } catch {
            viewModel.saveError = "Couldn’t save to Plink. Open Plink once, then try again."
        }
    }

    /// The first web link in a shared item: a URL, or text containing one
    /// (Instagram, TikTok and others share "Check this out https://…").
    static func extractURL(from provider: NSItemProvider) async -> URL? {
        for type in [UTType.url.identifier, UTType.plainText.identifier] {
            guard provider.hasItemConformingToTypeIdentifier(type) else { continue }
            guard let item = try? await provider.loadItem(forTypeIdentifier: type) else { continue }
            if let url = item as? URL, url.scheme?.hasPrefix("http") == true { return url }
            if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil),
               url.scheme?.hasPrefix("http") == true { return url }
            if let text = item as? String, let url = firstLink(in: text) { return url }
        }
        return nil
    }

    static func firstLink(in text: String) -> URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(text.startIndex..., in: text)
        return detector?.matches(in: text, range: range)
            .compactMap(\.url)
            .first { $0.scheme?.hasPrefix("http") == true }
    }
}

// MARK: - View Model

@MainActor
@Observable
final class SharePreviewViewModel {
    var url: URL?
    var domain = ""
    var title = ""
    var previewImage: UIImage?
    var isLoading = true
    var isFetchingPreview = false
    var boards: [BoardInfo] = []
    var selectedBoardIDs: Set<String> = []
    var saveError: String?

    func setURL(_ url: URL) {
        self.url = url
        domain = url.host(percentEncoded: false)?.replacingOccurrences(of: "www.", with: "") ?? ""
        isLoading = false
        isFetchingPreview = true
        Task {
            if let metadata = try? await LPMetadataProvider().startFetchingMetadata(for: url) {
                title = metadata.title ?? ""
                if let provider = metadata.imageProvider ?? metadata.iconProvider {
                    previewImage = await Self.loadImage(from: provider)
                }
            }
            isFetchingPreview = false
        }
    }

    private static func loadImage(from provider: NSItemProvider) async -> UIImage? {
        await withCheckedContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                continuation.resume(returning: data.flatMap(UIImage.init(data:)))
            }
        }
    }
}

// MARK: - View

struct ShareExtensionView: View {
    @Bindable var viewModel: SharePreviewViewModel
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Save to Plink")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", action: onCancel)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save", action: onSave)
                            .fontWeight(.semibold)
                            .disabled(viewModel.url == nil)
                    }
                }
        }
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.url != nil {
                    linkCard
                } else if viewModel.isLoading {
                    ProgressView("Loading link…")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else {
                    ContentUnavailableView(
                        "No Link Found",
                        systemImage: "link.badge.plus",
                        description: Text("Plink saves web links. This item doesn’t contain one.")
                    )
                }

                if let error = viewModel.saveError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                if !viewModel.boards.isEmpty {
                    boardGrid
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
    }

    private var linkCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let image = viewModel.previewImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
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
                        .font(.subheadline.weight(.semibold))
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
    }

    private var boardGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Save to Board")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 10)], spacing: 10) {
                ForEach(viewModel.boards) { board in
                    let selected = viewModel.selectedBoardIDs.contains(board.id)
                    Button {
                        if selected {
                            viewModel.selectedBoardIDs.remove(board.id)
                        } else {
                            viewModel.selectedBoardIDs.insert(board.id)
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: UIImage(systemName: board.symbol) != nil ? board.symbol : "folder")
                                .font(.title2)
                                .frame(height: 28)
                            Text(board.name)
                                .font(.caption)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, minHeight: 72)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 10)
                        .background(selected ? plinkAmber.opacity(0.15) : Color.secondary.opacity(0.1))
                        .foregroundStyle(selected ? plinkAmber : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selected ? plinkAmber : .clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }
}
