import AppKit
import Foundation
import SwiftData
@testable import RedditReminder

@MainActor
func makeBackupContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
        for: Project.self, Capture.self, Subreddit.self, SubredditEvent.self,
        configurations: config
    )
}

func temporaryBackupMediaRoot() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
}

func backupTestImage() -> NSImage {
    let image = NSImage(size: NSSize(width: 32, height: 32))
    image.lockFocus()
    NSColor.systemBlue.setFill()
    NSRect(x: 0, y: 0, width: 32, height: 32).fill()
    image.unlockFocus()
    return image
}
