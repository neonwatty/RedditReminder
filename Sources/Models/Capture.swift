import Foundation
import SwiftData

enum CaptureStatus: String, Codable {
    case queued
    case posted
}

@Model
final class Capture {
    var id: UUID
    var text: String
    var notes: String?
    var links: [String]
    var mediaRefs: [String]
    var status: CaptureStatus
    var createdAt: Date
    var postedAt: Date?

    var project: Project?
    var subreddits: [Subreddit]

    init(
        text: String,
        notes: String? = nil,
        links: [String] = [],
        mediaRefs: [String] = [],
        project: Project? = nil,
        subreddits: [Subreddit] = []
    ) {
        self.id = UUID()
        self.text = text
        self.notes = notes
        self.links = links
        self.mediaRefs = mediaRefs
        self.status = .queued
        self.createdAt = Date()
        self.postedAt = nil
        self.project = project
        self.subreddits = subreddits
    }

    func markAsPosted() {
        self.status = .posted
        self.postedAt = Date()
    }

    func markAsQueued() {
        self.status = .queued
        self.postedAt = nil
    }
}
