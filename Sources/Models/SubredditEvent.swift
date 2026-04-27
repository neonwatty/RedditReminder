import Foundation
import SwiftData

@Model
final class SubredditEvent {
    var id: UUID
    var name: String
    var rrule: String?
    var oneOffDate: Date?
    var reminderLeadMinutes: Int
    var isActive: Bool

    var subreddit: Subreddit?

    var isRecurring: Bool {
        rrule != nil
    }

    init(
        name: String,
        subreddit: Subreddit,
        rrule: String? = nil,
        oneOffDate: Date? = nil,
        reminderLeadMinutes: Int = 60,
        isActive: Bool = true
    ) {
        self.id = UUID()
        self.name = name
        self.rrule = rrule
        self.oneOffDate = oneOffDate
        self.reminderLeadMinutes = max(0, reminderLeadMinutes)
        self.isActive = isActive
        self.subreddit = subreddit
    }
}
