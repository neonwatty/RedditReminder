import AppKit
import Foundation
import SwiftData
import Testing
@testable import RedditReminder

@Test @MainActor func backupExportEmbedsExistingMediaFiles() throws {
    let container = try makeBackupContainer()
    let context = ModelContext(container)
    let mediaStore = MediaStore(rootDir: temporaryBackupMediaRoot())
    let capture = Capture(text: "With media")
    context.insert(capture)
    let ref = try mediaStore.save(image: backupTestImage(), captureId: capture.id, fileName: "image.png")
    capture.mediaRefs = [ref]
    try context.save()

    let data = try BackupService().exportBackup(from: context, mediaStore: mediaStore)
    let backup = try JSONDecoder().decode(AppBackup.self, from: data)

    #expect(backup.mediaFiles?.count == 1)
    #expect(backup.mediaFiles?[0].captureId == capture.id)
    #expect(backup.mediaFiles?[0].ref == ref)
    #expect(backup.mediaFiles?[0].data.isEmpty == false)
}

@Test @MainActor func backupImportRestoresEmbeddedMediaFiles() throws {
    let sourceContainer = try makeBackupContainer()
    let sourceContext = ModelContext(sourceContainer)
    let sourceMediaStore = MediaStore(rootDir: temporaryBackupMediaRoot())
    let sourceCapture = Capture(text: "With media")
    sourceContext.insert(sourceCapture)
    let ref = try sourceMediaStore.save(
        image: backupTestImage(),
        captureId: sourceCapture.id,
        fileName: "image.png"
    )
    sourceCapture.mediaRefs = [ref]
    try sourceContext.save()
    let data = try BackupService().exportBackup(from: sourceContext, mediaStore: sourceMediaStore)

    let destinationContainer = try makeBackupContainer()
    let destinationContext = ModelContext(destinationContainer)
    let destinationMediaStore = MediaStore(rootDir: temporaryBackupMediaRoot())

    try BackupService().importBackup(
        from: data,
        into: destinationContext,
        mediaStore: destinationMediaStore
    )

    let captures = try destinationContext.fetch(FetchDescriptor<Capture>())
    #expect(captures.count == 1)
    #expect(captures[0].mediaRefs == [ref])
    #expect(destinationMediaStore.loadImage(captureId: sourceCapture.id, ref: ref) != nil)
    #expect(destinationMediaStore.loadThumbnail(captureId: sourceCapture.id, ref: ref) != nil)
}

@Test @MainActor func backupImportRejectsEmbeddedMediaWithInvalidRefsBeforeClearingData() throws {
    let container = try makeBackupContainer()
    let context = ModelContext(container)
    let existing = Capture(text: "Existing")
    context.insert(existing)
    try context.save()

    let mediaRoot = temporaryBackupMediaRoot()
    let mediaStore = MediaStore(rootDir: mediaRoot)
    let outsideURL = mediaRoot.deletingLastPathComponent().appendingPathComponent("outside.png")
    try? FileManager.default.removeItem(at: outsideURL)
    let importedCaptureId = UUID()
    let backup = AppBackup(
        settings: BackupSettings(),
        projects: [],
        subreddits: [],
        events: [],
        captures: [
            BackupCapture(
                id: importedCaptureId,
                text: "Imported",
                notes: nil,
                links: [],
                mediaRefs: ["../outside.png"],
                status: .queued,
                createdAt: Date(),
                postedAt: nil,
                projectId: nil,
                subredditIds: []
            )
        ],
        mediaFiles: [
            BackupMediaFile(
                captureId: importedCaptureId,
                ref: "../outside.png",
                data: try backupPNGFixtureData()
            )
        ]
    )
    let data = try JSONEncoder().encode(backup)

    do {
        try BackupService().importBackup(from: data, into: context, mediaStore: mediaStore)
        Issue.record("Expected invalid media reference error")
    } catch MediaError.invalidReference {
        let captures = try context.fetch(FetchDescriptor<Capture>())
        #expect(captures.map(\.text) == ["Existing"])
        #expect(!FileManager.default.fileExists(atPath: outsideURL.path))
    } catch {
        throw error
    }
}

private func backupPNGFixtureData() throws -> Data {
    let image = backupTestImage()
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        throw MediaError.encodingFailed
    }
    return png
}
