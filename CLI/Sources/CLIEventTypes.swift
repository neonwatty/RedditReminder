import Foundation

struct EventListInput {
  let query: String?
  let subreddit: String?
  let from: Date?
  let to: Date?
  let generated: Bool?
  let active: Bool?

  init(
    query: String?,
    subreddit: String?,
    from: Date?,
    to: Date?,
    generated: Bool?,
    active: Bool?
  ) throws {
    if let from, let to, from > to {
      throw CLIError.validation("--from must be before --to.")
    }
    self.query = query
    self.subreddit = subreddit
    self.from = from
    self.to = to
    self.generated = generated
    self.active = active
  }
}

struct EventCreateInput {
  let name: String?
  let subreddit: String
  let date: Date
  let leadMinutes: Int?
}

struct EventUpdateInput {
  let id: String
  let name: String?
  let date: Date?
  let leadMinutes: Int?
  let active: Bool?

  var hasChanges: Bool {
    name != nil || date != nil || leadMinutes != nil || active != nil
  }
}

struct EventDTO: Encodable {
  let id: String
  let name: String
  let subreddit: SubredditRefDTO?
  let oneOffDate: String?
  let rrule: String?
  let recurrenceHour: Int?
  let recurrenceMinute: Int?
  let timeZone: String?
  let reminderLeadMinutes: Int
  let isActive: Bool
  let isGeneratedFromHeuristics: Bool
  let generationKey: String?

  init(_ event: SubredditEvent) {
    id = event.id.uuidString
    name = event.name
    subreddit = event.subreddit.map(SubredditRefDTO.init)
    oneOffDate = event.oneOffDate.map(CLIFormat.date)
    rrule = event.rrule
    recurrenceHour = event.recurrenceHour
    recurrenceMinute = event.recurrenceMinute
    timeZone = event.recurrenceTimeZoneIdentifier
    reminderLeadMinutes = event.reminderLeadMinutes
    isActive = event.isActive
    isGeneratedFromHeuristics = event.isGeneratedFromHeuristics
    generationKey = event.generationKey
  }
}
