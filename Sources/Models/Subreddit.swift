import Foundation
import SwiftData

@Model
final class Subreddit {
    var id: UUID
    var name: String
    var peakDaysOverride: [String]?
    var peakHoursUtcOverride: [Int]?

    @Relationship(deleteRule: .cascade, inverse: \SubredditEvent.subreddit)
    var events: [SubredditEvent]

    init(
        name: String,
        peakDaysOverride: [String]? = nil,
        peakHoursUtcOverride: [Int]? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.peakDaysOverride = peakDaysOverride
        self.peakHoursUtcOverride = peakHoursUtcOverride
        self.events = []
    }
}
