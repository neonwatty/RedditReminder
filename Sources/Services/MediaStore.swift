import Foundation
import AppKit

final class MediaStore {
  private let rootDir: URL
  private let fm = FileManager.default

  init(rootDir: URL? = nil) {
    if let rootDir {
      self.rootDir = rootDir
    } else {
      let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      self.rootDir = appSupport.appendingPathComponent("RedditReminder/media")
    }
  }

  func save(image: NSImage, captureId: UUID, fileName: String) throws -> String {
    let captureDir = rootDir.appendingPathComponent(captureId.uuidString)
    let thumbDir = captureDir.appendingPathComponent("thumbnails")
    try fm.createDirectory(at: captureDir, withIntermediateDirectories: true)
    try fm.createDirectory(at: thumbDir, withIntermediateDirectories: true)

    guard let data = pngData(from: image) else {
      throw MediaError.encodingFailed
    }
    let storedName = uniqueFileName(fileName, in: captureDir)
    let fileURL = captureDir.appendingPathComponent(storedName)
    try data.write(to: fileURL)

    let thumbnail = generateThumbnail(from: image, maxSize: MediaConstants.thumbnailMaxSize)
    if let thumbData = pngData(from: thumbnail) {
      let thumbURL = thumbDir.appendingPathComponent(storedName)
      do {
        try thumbData.write(to: thumbURL)
      } catch {
        NSLog("RedditReminder: failed to write thumbnail: \(error)")
      }
    } else {
      NSLog("RedditReminder: failed to encode thumbnail PNG for \(storedName)")
    }

    return storedName
  }

  func saveFile(at sourceURL: URL, captureId: UUID) throws -> String {
    let ext = sourceURL.pathExtension.lowercased()
    guard MediaConstants.supportedImageTypes.contains(ext) else {
      throw MediaError.unsupportedType
    }
    guard let image = NSImage(contentsOf: sourceURL) else {
      throw MediaError.decodingFailed
    }
    return try save(image: image, captureId: captureId, fileName: sourceURL.lastPathComponent)
  }

  func loadImage(captureId: UUID, ref: String) -> NSImage? {
    guard isValidMediaRef(ref) else { return nil }
    let url = rootDir
      .appendingPathComponent(captureId.uuidString)
      .appendingPathComponent(ref)
    return NSImage(contentsOf: url)
  }

  func loadThumbnail(captureId: UUID, ref: String) -> NSImage? {
    guard isValidMediaRef(ref) else { return nil }
    let url = rootDir
      .appendingPathComponent(captureId.uuidString)
      .appendingPathComponent("thumbnails")
      .appendingPathComponent(ref)
    return NSImage(contentsOf: url)
  }

  func mediaURL(captureId: UUID, ref: String) -> URL {
    rootDir
      .appendingPathComponent(captureId.uuidString)
      .appendingPathComponent(ref)
  }

  func thumbnailURL(captureId: UUID, ref: String) -> URL {
    rootDir
      .appendingPathComponent(captureId.uuidString)
      .appendingPathComponent("thumbnails")
      .appendingPathComponent(ref)
  }

  func exists(captureId: UUID, ref: String) -> Bool {
    guard isValidMediaRef(ref) else { return false }
    return fm.fileExists(atPath: mediaURL(captureId: captureId, ref: ref).path)
  }

  func delete(captureId: UUID, ref: String) {
    guard isValidMediaRef(ref) else { return }
    for url in [mediaURL(captureId: captureId, ref: ref), thumbnailURL(captureId: captureId, ref: ref)] {
      do {
        try fm.removeItem(at: url)
      } catch CocoaError.fileNoSuchFile {
        continue
      } catch {
        NSLog("RedditReminder: failed to delete media ref \(ref) for \(captureId): \(error)")
      }
    }
  }

  func deleteAll(captureId: UUID) {
    let dir = rootDir.appendingPathComponent(captureId.uuidString)
    do {
      try fm.removeItem(at: dir)
    } catch CocoaError.fileNoSuchFile {
      // Directory already absent — nothing to clean up
    } catch {
      NSLog("RedditReminder: failed to delete media for \(captureId): \(error)")
    }
  }

  private func generateThumbnail(from image: NSImage, maxSize: CGFloat) -> NSImage {
    let originalSize = image.size
    let aspect = originalSize.width / originalSize.height

    let size: NSSize
    if originalSize.width > originalSize.height {
      size = NSSize(width: maxSize, height: maxSize / aspect)
    } else {
      size = NSSize(width: maxSize * aspect, height: maxSize)
    }

    let thumbnail = NSImage(size: size)
    thumbnail.lockFocus()
    image.draw(
      in: NSRect(origin: .zero, size: size),
      from: NSRect(origin: .zero, size: originalSize),
      operation: .copy,
      fraction: 1.0
    )
    thumbnail.unlockFocus()
    return thumbnail
  }

  private func uniqueFileName(_ fileName: String, in directory: URL) -> String {
    let rawBase = URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
    let rawExt = URL(fileURLWithPath: fileName).pathExtension
    let base = rawBase.isEmpty ? "media" : rawBase
    let ext = rawExt.isEmpty ? "png" : rawExt

    var candidate = "\(base).\(ext)"
    var index = 1
    while fm.fileExists(atPath: directory.appendingPathComponent(candidate).path) {
      candidate = "\(base)-\(index).\(ext)"
      index += 1
    }
    return candidate
  }

  private func isValidMediaRef(_ ref: String) -> Bool {
    !ref.isEmpty &&
      ref != "." &&
      ref != ".." &&
      !ref.contains("/") &&
      !ref.contains("\\") &&
      URL(fileURLWithPath: ref).lastPathComponent == ref
  }

  private func pngData(from image: NSImage) -> Data? {
    guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:])
    else { return nil }
    return png
  }
}

enum MediaError: Error {
  case decodingFailed
  case encodingFailed
  case unsupportedType
}
