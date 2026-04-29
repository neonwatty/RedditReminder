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
