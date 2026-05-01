import Foundation
import SwiftData

enum CaptureStatus: String, Codable {
  case queued
  case posted
}

@Model
final class Capture {
  var id: UUID
  var title: String?
  var text: String
  var notes: String?
  var links: [String]
  var mediaRefs: [String]
  var status: CaptureStatus
  var createdAt: Date
  var postedAt: Date?
  var postedURL: String?
  var postedSubredditIDs: [UUID] = []

  var project: Project?
  var subreddits: [Subreddit]

  init(
    title: String? = nil,
    text: String,
    notes: String? = nil,
    links: [String] = [],
    mediaRefs: [String] = [],
    project: Project? = nil,
    subreddits: [Subreddit] = []
  ) {
    self.id = UUID()
    self.title = title
    self.text = text
    self.notes = notes
    self.links = links
    self.mediaRefs = mediaRefs
    self.status = .queued
    self.createdAt = Date()
    self.postedAt = nil
    self.postedURL = nil
    self.postedSubredditIDs = []
    self.project = project
    self.subreddits = subreddits
  }

  func markAsPosted(postedURL: String? = nil) {
    self.status = .posted
    self.postedAt = Date()
    self.postedURL = postedURL
    self.postedSubredditIDs = subreddits.map(\.id)
  }

  func markAsQueued() {
    self.status = .queued
    self.postedAt = nil
    self.postedURL = nil
    self.postedSubredditIDs = []
  }

  func markSubredditAsPosted(_ subredditId: UUID) {
    guard !postedSubredditIDs.contains(subredditId) else { return }
    postedSubredditIDs.append(subredditId)
    if Set(postedSubredditIDs) == Set(subreddits.map(\.id)) {
      status = .posted
      postedAt = Date()
    }
  }

  func markSubredditAsUnposted(_ subredditId: UUID) {
    postedSubredditIDs.removeAll { $0 == subredditId }
    if status == .posted {
      status = .queued
      postedAt = nil
    }
  }
}
