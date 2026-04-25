import Testing
import Foundation
import AppKit
@testable import RedditReminder

@Test func saveAndLoadMedia() throws {
  let store = MediaStore(
    rootDir: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
  let image = createTestImage(width: 800, height: 600)
  let captureId = UUID()

  let ref = try store.save(image: image, captureId: captureId, fileName: "test.png")
  #expect(ref == "test.png")

  let loaded = store.loadImage(captureId: captureId, ref: ref)
  #expect(loaded != nil)
}

@Test func thumbnailIsSmallerThanOriginal() throws {
  let store = MediaStore(
    rootDir: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
  let image = createTestImage(width: 800, height: 600)
  let captureId = UUID()

  _ = try store.save(image: image, captureId: captureId, fileName: "big.png")
  let thumb = store.loadThumbnail(captureId: captureId, ref: "big.png")
  #expect(thumb != nil)
  #expect(thumb!.size.width <= 200)
  #expect(thumb!.size.height <= 200)
}

@Test func deleteRemovesFiles() throws {
  let store = MediaStore(
    rootDir: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
  let image = createTestImage(width: 100, height: 100)
  let captureId = UUID()

  _ = try store.save(image: image, captureId: captureId, fileName: "del.png")
  store.deleteAll(captureId: captureId)

  let loaded = store.loadImage(captureId: captureId, ref: "del.png")
  #expect(loaded == nil)
}

private func createTestImage(width: Int, height: Int) -> NSImage {
  let image = NSImage(size: NSSize(width: width, height: height))
  image.lockFocus()
  NSColor.red.setFill()
  NSRect(x: 0, y: 0, width: width, height: height).fill()
  image.unlockFocus()
  return image
}
