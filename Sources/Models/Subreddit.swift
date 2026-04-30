import Foundation
import SwiftData

@Model
final class Subreddit {
  var id: UUID
  var name: String
  var sortOrder: Int = 0
  var peakDaysOverride: [String]?
  var peakHoursUtcOverride: [Int]?
  var postingChecklist: String?

  @Relationship(deleteRule: .cascade, inverse: \SubredditEvent.subreddit)
  var events: [SubredditEvent]

  @Relationship(inverse: \Capture.subreddits)
  var captures: [Capture]

  init(
    name: String,
    sortOrder: Int = 0,
    peakDaysOverride: [String]? = nil,
    peakHoursUtcOverride: [Int]? = nil,
    postingChecklist: String? = nil
  ) {
    self.id = UUID()
    self.name = name
    self.sortOrder = sortOrder
    self.peakDaysOverride = peakDaysOverride
    self.peakHoursUtcOverride = peakHoursUtcOverride
    self.postingChecklist = postingChecklist
    self.events = []
    self.captures = []
  }
}
