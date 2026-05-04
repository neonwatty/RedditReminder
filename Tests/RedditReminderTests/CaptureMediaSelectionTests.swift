import Foundation
import Testing
@testable import RedditReminder

@Test func mediaSelectionKeepsImageAndVideoURLsAndRejectsTextFiles() throws {
    let imageURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("\(UUID().uuidString).png")
    let videoURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("\(UUID().uuidString).mp4")
    let textURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("\(UUID().uuidString).txt")
    try Data([0x89, 0x50, 0x4E, 0x47]).write(to: imageURL)
    try Data([0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70]).write(to: videoURL)
    try "not an image".write(to: textURL, atomically: true, encoding: .utf8)
    defer {
        try? FileManager.default.removeItem(at: imageURL)
        try? FileManager.default.removeItem(at: videoURL)
        try? FileManager.default.removeItem(at: textURL)
    }

    let result = CaptureMediaSelection.result(from: [imageURL, videoURL, textURL])
    #expect(result.mediaURLs == [imageURL, videoURL])
    #expect(result.rejectedCount == 1)
    #expect(CaptureMediaSelection.mediaURLs(from: [imageURL, videoURL, textURL]) == [imageURL, videoURL])
    #expect(CaptureMediaSelection.imageURLs(from: [imageURL, videoURL, textURL]) == [imageURL, videoURL])
}

@Test func mediaSelectionAllowsDuplicateImageURLs() throws {
    let imageURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("\(UUID().uuidString).jpg")
    try Data([0xFF, 0xD8, 0xFF, 0xD9]).write(to: imageURL)
    defer { try? FileManager.default.removeItem(at: imageURL) }

    #expect(CaptureMediaSelection.imageURLs(from: [imageURL, imageURL]) == [imageURL, imageURL])
}
