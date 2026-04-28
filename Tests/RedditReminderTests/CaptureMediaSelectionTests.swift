import Foundation
import Testing
@testable import RedditReminder

@Test func mediaSelectionKeepsImageURLsAndRejectsTextFiles() throws {
    let imageURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("\(UUID().uuidString).png")
    let textURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("\(UUID().uuidString).txt")
    try Data([0x89, 0x50, 0x4E, 0x47]).write(to: imageURL)
    try "not an image".write(to: textURL, atomically: true, encoding: .utf8)
    defer {
        try? FileManager.default.removeItem(at: imageURL)
        try? FileManager.default.removeItem(at: textURL)
    }

    #expect(CaptureMediaSelection.imageURLs(from: [imageURL, textURL]) == [imageURL])
}

@Test func mediaSelectionAllowsDuplicateImageURLs() throws {
    let imageURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("\(UUID().uuidString).jpg")
    try Data([0xFF, 0xD8, 0xFF, 0xD9]).write(to: imageURL)
    defer { try? FileManager.default.removeItem(at: imageURL) }

    #expect(CaptureMediaSelection.imageURLs(from: [imageURL, imageURL]) == [imageURL, imageURL])
}
