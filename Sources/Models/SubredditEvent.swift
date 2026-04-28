import Foundation
import SwiftData

@Model
final class SubredditEvent {
    var id: UUID
    var name: String
    var rrule: String?
    var oneOffDate: Date?
    var recurrenceHour: Int?
    var recurrenceMinute: Int?
    var recurrenceTimeZoneIdentifier: String?
    var reminderLeadMinutes: Int {
        didSet { reminderLeadMinutes = max(0, reminderLeadMinutes) }
    }
    var isActive: Bool
    var isGeneratedFromHeuristics: Bool = false
    var generationKey: String?

    var subreddit: Subreddit?

    var isRecurring: Bool {
        rrule != nil
    }

    init(
        name: String,
        subreddit: Subreddit,
        rrule: String? = nil,
        oneOffDate: Date? = nil,
        recurrenceHour: Int? = nil,
        recurrenceMinute: Int? = nil,
        recurrenceTimeZoneIdentifier: String? = nil,
        reminderLeadMinutes: Int = 60,
        isActive: Bool = true,
        isGeneratedFromHeuristics: Bool = false,
        generationKey: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.rrule = rrule
        self.oneOffDate = oneOffDate
        self.recurrenceHour = recurrenceHour.map { min(23, max(0, $0)) }
        self.recurrenceMinute = recurrenceMinute.map { min(59, max(0, $0)) }
        self.recurrenceTimeZoneIdentifier = recurrenceTimeZoneIdentifier
        self.reminderLeadMinutes = max(0, reminderLeadMinutes)
        self.isActive = isActive
        self.isGeneratedFromHeuristics = isGeneratedFromHeuristics
        self.generationKey = generationKey
        self.subreddit = subreddit
    }
}
