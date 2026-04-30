import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct BackupSectionView: View {
    var onAppStateChanged: AppRefreshAction = {}

    @Environment(\.modelContext) private var modelContext

    @State private var exportDocument: BackupDocument?
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var pendingImport: PendingBackupImport?
    @State private var statusMessage: String?
    @State private var errorMessage: String?

    private let backupService = BackupService()
    private let mediaStore = MediaStore()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button("Export Backup") {
                    exportBackup()
                }
                .font(.system(size: 11))

                Button("Import Backup") {
                    isImporting = true
                }
                .font(.system(size: 11))

                Spacer()
            }

            if let statusMessage {
                Text(statusMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            }
        }
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "RedditReminder Backup"
        ) { result in
            handleExportResult(result)
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            previewImport(result)
        }
        .alert("Replace Current Data?", isPresented: pendingImportIsPresented, presenting: pendingImport) { pendingImport in
            Button("Replace Data", role: .destructive) {
                confirmImport(pendingImport)
            }
            Button("Cancel", role: .cancel) {
                self.pendingImport = nil
            }
        } message: { pendingImport in
            Text(
                "This backup contains \(pendingImport.preview.importSummary). Importing it will replace the current app data."
            )
        }
    }

    private func exportBackup() {
        do {
            let data = try backupService.exportBackup(from: modelContext, mediaStore: mediaStore)
            exportDocument = BackupDocument(data: data)
            isExporting = true
            statusMessage = nil
            errorMessage = nil
        } catch {
            statusMessage = nil
            errorMessage = "Export failed: \(error.localizedDescription)"
        }
    }

    private func previewImport(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let didAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didAccess { url.stopAccessingSecurityScopedResource() }
            }
            let data = try Data(contentsOf: url)
            let preview = try backupService.previewBackup(from: data)
            pendingImport = PendingBackupImport(data: data, preview: preview)
            statusMessage = "Backup ready to import: \(preview.importSummary)"
            errorMessage = nil
        } catch {
            pendingImport = nil
            statusMessage = nil
            errorMessage = "Import failed: \(error.localizedDescription)"
        }
    }

    private func confirmImport(_ pendingImport: PendingBackupImport) {
        do {
            let result = try backupService.importBackup(
                from: pendingImport.data,
                into: modelContext,
                mediaStore: mediaStore
            )
            self.pendingImport = nil
            statusMessage = "Backup imported: \(result.preview.importSummary)"
            errorMessage = nil
            onAppStateChanged()
        } catch {
            self.pendingImport = nil
            statusMessage = nil
            errorMessage = "Import failed: \(error.localizedDescription)"
        }
    }

    private var pendingImportIsPresented: Binding<Bool> {
        Binding(
            get: { pendingImport != nil },
            set: { isPresented in
                if !isPresented { pendingImport = nil }
            }
        )
    }

    private func handleExportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success:
            statusMessage = "Backup exported"
            errorMessage = nil
        case .failure(let error):
            statusMessage = nil
            errorMessage = "Export failed: \(error.localizedDescription)"
        }
    }
}

private struct PendingBackupImport: Identifiable {
    let id = UUID()
    let data: Data
    let preview: BackupPreview
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data = Data()) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
