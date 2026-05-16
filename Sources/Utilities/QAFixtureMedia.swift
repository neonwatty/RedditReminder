import AppKit

extension QAFixtures {
  @MainActor
  static func attachFixtureMedia(to capture: Capture, mediaStore: MediaStore?) {
    guard let mediaStore else {
      capture.mediaRefs = ["qa-menu-bar-screenshot.png"]
      return
    }

    do {
      let image = makeFixtureImage()
      capture.mediaRefs = [
        try mediaStore.save(
          image: image,
          captureId: capture.id,
          fileName: "qa-menu-bar-screenshot.png"
        )
      ]
    } catch {
      NSLog("RedditReminder: failed to seed QA media: \(error)")
    }
  }

  private static func makeFixtureImage() -> NSImage {
    let size = NSSize(width: 640, height: 360)
    let image = NSImage(size: size)
    image.lockFocus()

    NSColor(calibratedRed: 0.10, green: 0.12, blue: 0.15, alpha: 1).setFill()
    NSRect(origin: .zero, size: size).fill()

    NSColor(calibratedRed: 1.00, green: 0.28, blue: 0.04, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 44, y: 248, width: 552, height: 54), xRadius: 12, yRadius: 12)
      .fill()

    NSColor(calibratedRed: 0.20, green: 0.67, blue: 0.41, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 64, y: 72, width: 220, height: 132), xRadius: 16, yRadius: 16)
      .fill()

    NSColor(calibratedRed: 0.25, green: 0.36, blue: 0.95, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 324, y: 72, width: 252, height: 132), xRadius: 16, yRadius: 16)
      .fill()

    let title = "RedditReminder QA"
    let attrs: [NSAttributedString.Key: Any] = [
      .foregroundColor: NSColor.white,
      .font: NSFont.boldSystemFont(ofSize: 30)
    ]
    title.draw(at: NSPoint(x: 64, y: 258), withAttributes: attrs)

    image.unlockFocus()
    return image
  }
}
