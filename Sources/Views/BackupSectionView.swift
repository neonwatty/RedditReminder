import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct BackupSectionView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var exportDocument: BackupDocument?
    @State private var isExporting = false
    @State private var isImporting = false
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
            importBackup(result)
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
            errorMessage = "Export failed: \(error.localizedDescription)"
        }
    }

    private func importBackup(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let didAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didAccess { url.stopAccessingSecurityScopedResource() }
            }
            let data = try Data(contentsOf: url)
            try backupService.importBackup(from: data, into: modelContext, mediaStore: mediaStore)
            statusMessage = "Backup imported"
            errorMessage = nil
        } catch {
            errorMessage = "Import failed: \(error.localizedDescription)"
        }
    }

    private func handleExportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success:
            statusMessage = "Backup exported"
            errorMessage = nil
        case .failure(let error):
            errorMessage = "Export failed: \(error.localizedDescription)"
        }
    }
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
