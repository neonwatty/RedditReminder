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

@Test func saveFileCopiesDroppedImageIntoMediaStore() throws {
  let rootDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  let store = MediaStore(rootDir: rootDir)
  let sourceURL = rootDir
    .deletingLastPathComponent()
    .appendingPathComponent("\(UUID().uuidString).png")
  let image = createTestImage(width: 120, height: 80)
  guard let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let png = bitmap.representation(using: .png, properties: [:]) else {
    Issue.record("Failed to create PNG fixture")
    return
  }
  try png.write(to: sourceURL)
  defer { try? FileManager.default.removeItem(at: sourceURL) }

  let captureId = UUID()
  let ref = try store.saveFile(at: sourceURL, captureId: captureId)

  #expect(ref == sourceURL.lastPathComponent)
  #expect(store.loadImage(captureId: captureId, ref: ref) != nil)
  #expect(store.loadThumbnail(captureId: captureId, ref: ref) != nil)
}

@Test func saveFileGeneratesUniqueRefsForDuplicateNames() throws {
  let rootDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  let store = MediaStore(rootDir: rootDir)
  let sourceURL = rootDir
    .deletingLastPathComponent()
    .appendingPathComponent("duplicate.png")
  let image = createTestImage(width: 120, height: 80)
  guard let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let png = bitmap.representation(using: .png, properties: [:]) else {
    Issue.record("Failed to create PNG fixture")
    return
  }
  try png.write(to: sourceURL)
  defer { try? FileManager.default.removeItem(at: sourceURL) }

  let captureId = UUID()
  let first = try store.saveFile(at: sourceURL, captureId: captureId)
  let second = try store.saveFile(at: sourceURL, captureId: captureId)

  #expect(first == "duplicate.png")
  #expect(second == "duplicate-1.png")
  #expect(store.loadImage(captureId: captureId, ref: first) != nil)
  #expect(store.loadImage(captureId: captureId, ref: second) != nil)
}

@Test func deleteSingleMediaRefKeepsOtherMedia() throws {
  let rootDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  let store = MediaStore(rootDir: rootDir)
  let image = createTestImage(width: 120, height: 80)
  let captureId = UUID()

  let first = try store.save(image: image, captureId: captureId, fileName: "first.png")
  let second = try store.save(image: image, captureId: captureId, fileName: "second.png")

  store.delete(captureId: captureId, ref: first)

  #expect(store.loadImage(captureId: captureId, ref: first) == nil)
  #expect(store.loadThumbnail(captureId: captureId, ref: first) == nil)
  #expect(store.loadImage(captureId: captureId, ref: second) != nil)
  #expect(store.loadThumbnail(captureId: captureId, ref: second) != nil)
}

@Test func saveFileRejectsUnsupportedTypes() throws {
  let rootDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  let store = MediaStore(rootDir: rootDir)
  let sourceURL = rootDir
    .deletingLastPathComponent()
    .appendingPathComponent("\(UUID().uuidString).txt")
  try "not an image".write(to: sourceURL, atomically: true, encoding: .utf8)
  defer { try? FileManager.default.removeItem(at: sourceURL) }

  do {
    _ = try store.saveFile(at: sourceURL, captureId: UUID())
    Issue.record("Expected unsupported type error")
  } catch MediaError.unsupportedType {
    return
  } catch {
    throw error
  }
}

@Test func invalidMediaRefsDoNotLoadOrExist() throws {
  let rootDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  let store = MediaStore(rootDir: rootDir)
  let captureId = UUID()

  #expect(store.loadImage(captureId: captureId, ref: "../outside.png") == nil)
  #expect(store.loadThumbnail(captureId: captureId, ref: "nested/outside.png") == nil)
  #expect(!store.exists(captureId: captureId, ref: ""))
  #expect(!store.exists(captureId: captureId, ref: ".."))
}

@Test func deleteIgnoresInvalidMediaRefs() throws {
  let rootDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  let store = MediaStore(rootDir: rootDir)
  let image = createTestImage(width: 100, height: 100)
  let captureId = UUID()
  let otherCaptureId = UUID()
  let otherRef = try store.save(image: image, captureId: otherCaptureId, fileName: "other.png")

  store.delete(captureId: captureId, ref: "../\(otherCaptureId.uuidString)/\(otherRef)")

  #expect(store.loadImage(captureId: otherCaptureId, ref: otherRef) != nil)
  #expect(store.loadThumbnail(captureId: otherCaptureId, ref: otherRef) != nil)
}

private func createTestImage(width: Int, height: Int) -> NSImage {
  let image = NSImage(size: NSSize(width: width, height: height))
  image.lockFocus()
  NSColor.red.setFill()
  NSRect(x: 0, y: 0, width: width, height: height).fill()
  image.unlockFocus()
  return image
}
