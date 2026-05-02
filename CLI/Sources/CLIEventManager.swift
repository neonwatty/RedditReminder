import Foundation
import SwiftData

@MainActor
struct CLIEventManager {
  let options: CLIOptions
  let context: ModelContext

  func list(input: EventListInput) throws -> CLIResponse {
    let subreddit = try input.subreddit.map(findSubreddit)
    let events = fetchEvents().filter { event in
      matches(event, input: input, subreddit: subreddit)
    }
    return .success(data: .events(events.map(EventDTO.init)))
  }

  func create(input: EventCreateInput) throws -> CLIResponse {
    let subreddit = try findSubreddit(input.subreddit)
    let name = input.name ?? "Post window"
    if options.dryRun {
      return .success(data: .dryRun("Would create event \(name) for \(subreddit.name)."))
    }
    let event = SubredditEvent(
      name: name,
      subreddit: subreddit,
      oneOffDate: input.date,
      reminderLeadMinutes: input.leadMinutes ?? defaultLeadTimeMinutes,
      isActive: true,
      isGeneratedFromHeuristics: false
    )
    context.insert(event)
    try context.save()
    return .success(data: .event(EventDTO(event)))
  }

  func update(input: EventUpdateInput) throws -> CLIResponse {
    let event = try findEvent(input.id)
    try ensureManual(event)
    if options.dryRun {
      return .success(data: .dryRun("Would update event \(event.id.uuidString)."))
    }
    if let name = input.name { event.name = name }
    if let date = input.date { event.oneOffDate = date }
    if let leadMinutes = input.leadMinutes { event.reminderLeadMinutes = leadMinutes }
    if let active = input.active { event.isActive = active }
    try context.save()
    return .success(data: .event(EventDTO(event)))
  }

  func delete(id: String) throws -> CLIResponse {
    let event = try findEvent(id)
    try ensureManual(event)
    if options.dryRun {
      return .success(data: .dryRun("Would delete event \(event.id.uuidString)."))
    }
    let deletedId = event.id.uuidString
    context.delete(event)
    try context.save()
    return .success(data: .deleted(DeletedDTO(id: deletedId)))
  }

  private func fetchEvents() -> [SubredditEvent] {
    let descriptor = FetchDescriptor<SubredditEvent>(sortBy: [
      SortDescriptor(\.oneOffDate),
      SortDescriptor(\.name),
    ])
    return (try? context.fetch(descriptor)) ?? []
  }

  private func matches(
    _ event: SubredditEvent,
    input: EventListInput,
    subreddit: Subreddit?
  ) -> Bool {
    if let subreddit, event.subreddit?.id != subreddit.id { return false }
    if let generated = input.generated, event.isGeneratedFromHeuristics != generated {
      return false
    }
    if let active = input.active, event.isActive != active { return false }
    if let from = input.from, (event.oneOffDate ?? .distantPast) < from { return false }
    if let to = input.to, (event.oneOffDate ?? .distantFuture) > to { return false }
    guard let query = input.query?.lowercased(), !query.isEmpty else { return true }
    return [
      event.id.uuidString,
      event.name,
      event.subreddit?.name ?? "",
      event.rrule ?? "",
      event.generationKey ?? "",
    ].joined(separator: " ").lowercased().contains(query)
  }

  private func findEvent(_ input: String) throws -> SubredditEvent {
    let matches = fetchEvents().filter { event in
      event.id.uuidString == input || event.id.uuidString.lowercased().hasPrefix(input.lowercased())
    }
    if matches.count == 1, let event = matches.first { return event }
    if matches.count > 1 { throw CLIError.validation("Event id prefix is ambiguous: \(input)") }
    throw CLIError.notFound("Event not found: \(input)")
  }

  private func findSubreddit(_ input: String) throws -> Subreddit {
    let normalized = SubredditName.normalizedName(input) ?? input
    let descriptor = FetchDescriptor<Subreddit>(sortBy: [SortDescriptor(\.sortOrder)])
    let subreddits = (try? context.fetch(descriptor)) ?? []
    if let subreddit = subreddits.first(where: {
      $0.id.uuidString == input || $0.name.caseInsensitiveCompare(normalized) == .orderedSame
    }) {
      return subreddit
    }
    throw CLIError.notFound("Subreddit not found: \(input)")
  }

  private func ensureManual(_ event: SubredditEvent) throws {
    guard !event.isGeneratedFromHeuristics else {
      throw CLIError.validation(
        "Generated peak events cannot be updated or deleted directly. Use peaks set/reset."
      )
    }
  }

  private var defaultLeadTimeMinutes: Int {
    UserDefaults.standard.object(forKey: SettingsKey.defaultLeadTimeMinutes) as? Int ?? 60
  }
}
