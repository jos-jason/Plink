import SwiftUI
import SwiftData

struct SettingsView: View {
    @Query private var allPins: [Pin]
    @Query private var allBoards: [Board]
    @Environment(\.modelContext) private var modelContext

    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var exportDocument: PlinkDocument?
    @State private var showingImportConfirmation = false
    @State private var showingExportError = false
    @State private var showingImportError = false

    var body: some View {
        Form {
            Section("Library") {
                LabeledContent("Pins", value: "\(allPins.count)")
                LabeledContent("Boards", value: "\(allBoards.count)")
            }

            Section("Backup") {
                Button {
                    exportLibrary()
                } label: {
                    Label("Export Library", systemImage: "square.and.arrow.up")
                }

                Button {
                    showingImportConfirmation = true
                } label: {
                    Label("Import Library", systemImage: "square.and.arrow.down")
                }
            }

            Section("About") {
                LabeledContent("Version", value: appVersion)
                LabeledContent("App", value: "Plink")
            }
        }
        .navigationTitle("Settings")
        .fileExporter(
            isPresented: $showingExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "Plink-Backup-\(dateString).json"
        ) { result in
            if case .failure = result {
                showingExportError = true
            }
            exportDocument = nil
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.json]
        ) { result in
            importLibrary(result: result)
        }
        .alert("Export Failed", isPresented: $showingExportError) {
            Button("OK") {}
        } message: {
            Text("Could not export the library. Please try again.")
        }
        .alert("Import Failed", isPresented: $showingImportError) {
            Button("OK") {}
        } message: {
            Text("Could not read the backup file. Make sure it's a valid Plink export.")
        }
        .alert("Import Library?", isPresented: $showingImportConfirmation) {
            Button("Import") {
                showingImporter = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will add the pins and boards from the backup file to your library.")
        }
    }

    private func exportLibrary() {
        do {
            let data = try ExportService.exportJSON(
                pins: allPins, boards: allBoards
            )
            exportDocument = PlinkDocument(data: data)
            showingExporter = true
        } catch {
            showingExportError = true
        }
    }

    private func importLibrary(result: Result<URL, Error>) {
        do {
            let url = try result.get()
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            let data = try Data(contentsOf: url)
            try ExportService.importJSON(data: data, into: modelContext)
        } catch {
            showingImportError = true
        }
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}
