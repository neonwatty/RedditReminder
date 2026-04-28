import AppKit
import Foundation
import SwiftData
import Testing
@testable import RedditReminder

private func makeCapturePersistenceContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
        for: Project.self, Capture.self, Subreddit.self, SubredditEvent.self,
        configurations: config
    )
}

@Test @MainActor func saveCapturePersistsMediaRefsAndSignalsChange() throws {
    let container = try makeCapturePersistenceContainer()
    let context = ModelContext(container)
    let mediaStore = MediaStore(rootDir: temporaryMediaRoot())
    let subreddit = Subreddit(name: "r/SwiftUI")
    context.insert(subreddit)
    try context.save()

    let sourceURL = try writeTestImage(named: "draft.png")
    defer { try? FileManager.default.removeItem(at: sourceURL) }
    var changeCount = 0

    let ok = CapturePersistenceActions.saveCapture(
        CaptureFormResult(
            text: "Draft",
            notes: "Notes",
            links: ["https://example.com"],
            project: nil,
            subreddits: [subreddit],
            mediaURLs: [sourceURL]
        ),
        modelContext: context,
        mediaStore: mediaStore,
        onCaptureChanged: { changeCount += 1 }
    )

    let captures = try context.fetch(FetchDescriptor<Capture>())
    #expect(ok)
    #expect(changeCount == 1)
    #expect(captures.count == 1)
    #expect(captures[0].mediaRefs.count == 1)
    #expect(captures[0].mediaRefs[0].hasSuffix("draft.png"))
    #expect(mediaStore.loadImage(captureId: captures[0].id, ref: captures[0].mediaRefs[0]) != nil)
}

@Test @MainActor func updateCaptureRemovesDeletedMediaAfterSave() throws {
    let container = try makeCapturePersistenceContainer()
    let context = ModelContext(container)
    let mediaStore = MediaStore(rootDir: temporaryMediaRoot())
    let subreddit = Subreddit(name: "r/macOS")
    let capture = Capture(text: "Old", subreddits: [subreddit])
    context.insert(subreddit)
    context.insert(capture)
    let first = try mediaStore.save(image: testImage(), captureId: capture.id, fileName: "first.png")
    let second = try mediaStore.save(image: testImage(), captureId: capture.id, fileName: "second.png")
    capture.mediaRefs = [first, second]
    try context.save()

    let ok = CapturePersistenceActions.updateCapture(
        capture,
        with: CaptureFormResult(
            text: "Updated",
            notes: nil,
            links: [],
            project: nil,
            subreddits: [subreddit],
            mediaURLs: [],
            removedMediaRefs: [first]
        ),
        modelContext: context,
        mediaStore: mediaStore
    )

    #expect(ok)
    #expect(capture.text == "Updated")
    #expect(capture.mediaRefs == [second])
    #expect(mediaStore.loadImage(captureId: capture.id, ref: first) == nil)
    #expect(mediaStore.loadThumbnail(captureId: capture.id, ref: first) == nil)
    #expect(mediaStore.loadImage(captureId: capture.id, ref: second) != nil)
}

@Test @MainActor func updateCaptureRollsBackNewMediaWhenLaterFileFails() throws {
    let container = try makeCapturePersistenceContainer()
    let context = ModelContext(container)
    let mediaStore = MediaStore(rootDir: temporaryMediaRoot())
    let subreddit = Subreddit(name: "r/Swift")
    let capture = Capture(text: "Original", mediaRefs: [], subreddits: [subreddit])
    context.insert(subreddit)
    context.insert(capture)
    try context.save()

    let validURL = try writeTestImage(named: "valid.png")
    let invalidURL = try writeTextFile(named: "bad.txt")
    defer {
        try? FileManager.default.removeItem(at: validURL)
        try? FileManager.default.removeItem(at: invalidURL)
    }

    let ok = CapturePersistenceActions.updateCapture(
        capture,
        with: CaptureFormResult(
            text: "Changed",
            notes: nil,
            links: [],
            project: nil,
            subreddits: [subreddit],
            mediaURLs: [validURL, invalidURL]
        ),
        modelContext: context,
        mediaStore: mediaStore
    )

    #expect(!ok)
    #expect(capture.text == "Original")
    #expect(capture.mediaRefs.isEmpty)
    #expect(mediaStore.loadImage(captureId: capture.id, ref: validURL.lastPathComponent) == nil)
    #expect(mediaStore.loadThumbnail(captureId: capture.id, ref: validURL.lastPathComponent) == nil)
}

@Test @MainActor func deleteCaptureRemovesPersistedMedia() throws {
    let container = try makeCapturePersistenceContainer()
    let context = ModelContext(container)
    let mediaStore = MediaStore(rootDir: temporaryMediaRoot())
    let capture = Capture(text: "Delete me")
    context.insert(capture)
    let ref = try mediaStore.save(image: testImage(), captureId: capture.id, fileName: "delete.png")
    capture.mediaRefs = [ref]
    try context.save()
    let captureId = capture.id
    var changeCount = 0

    try CapturePersistenceActions.deleteCapture(
        capture,
        modelContext: context,
        mediaStore: mediaStore,
        onCaptureChanged: { changeCount += 1 }
    )

    #expect(changeCount == 1)
    #expect(try context.fetchCount(FetchDescriptor<Capture>()) == 0)
    #expect(mediaStore.loadImage(captureId: captureId, ref: ref) == nil)
    #expect(mediaStore.loadThumbnail(captureId: captureId, ref: ref) == nil)
}

private func temporaryMediaRoot() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
}

private func writeTestImage(named fileName: String) throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString)-\(fileName)")
    guard let tiff = testImage().tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        throw MediaError.encodingFailed
    }
    try png.write(to: url)
    return url
}

private func writeTextFile(named fileName: String) throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString)-\(fileName)")
    try "not media".write(to: url, atomically: true, encoding: .utf8)
    return url
}

private func testImage() -> NSImage {
    let image = NSImage(size: NSSize(width: 64, height: 64))
    image.lockFocus()
    NSColor.systemOrange.setFill()
    NSRect(x: 0, y: 0, width: 64, height: 64).fill()
    image.unlockFocus()
    return image
}
