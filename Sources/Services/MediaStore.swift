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
    let fileURL = captureDir.appendingPathComponent(fileName)
    try data.write(to: fileURL)

    let thumbnail = generateThumbnail(from: image, maxSize: MediaConstants.thumbnailMaxSize)
    if let thumbData = pngData(from: thumbnail) {
      let thumbURL = thumbDir.appendingPathComponent(fileName)
      do {
        try thumbData.write(to: thumbURL)
      } catch {
        NSLog("RedditReminder: failed to write thumbnail: \(error)")
      }
    }

    return fileName
  }

  func loadImage(captureId: UUID, ref: String) -> NSImage? {
    let url = rootDir
      .appendingPathComponent(captureId.uuidString)
      .appendingPathComponent(ref)
    return NSImage(contentsOf: url)
  }

  func loadThumbnail(captureId: UUID, ref: String) -> NSImage? {
    let url = rootDir
      .appendingPathComponent(captureId.uuidString)
      .appendingPathComponent("thumbnails")
      .appendingPathComponent(ref)
    return NSImage(contentsOf: url)
  }

  func deleteAll(captureId: UUID) {
    let dir = rootDir.appendingPathComponent(captureId.uuidString)
    do {
      try fm.removeItem(at: dir)
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

  private func pngData(from image: NSImage) -> Data? {
    guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:])
    else { return nil }
    return png
  }
}

enum MediaError: Error {
  case encodingFailed
}
