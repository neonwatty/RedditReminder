import Foundation
import SwiftData

@MainActor
struct CLISubredditManager {
  let options: CLIOptions
  let context: ModelContext
  let heuristicsStore: HeuristicsStore

  func list(query: String?) -> CLIResponse {
    let subreddits = fetchSubreddits(matching: query).map {
      SubredditDTO($0, peakInfo: heuristicsStore.peakInfo(for: $0))
    }
    return .success(data: .subreddits(subreddits))
  }

  func add(name input: String, verify: Bool) async throws -> CLIResponse {
    let subreddits = fetchSubreddits(matching: nil)
    let name = try normalizedSubredditName(input)
    guard !subreddits.contains(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame })
    else {
      throw CLIError.validation(SubredditName.ValidationError.duplicate.message)
    }
    if verify {
      let verification = try await SubredditVerifier().verify(name: name)
      guard verification.exists else {
        throw CLIError.validation("Subreddit could not be verified on Reddit: \(name)")
      }
    }
    if options.dryRun {
      return .success(data: .dryRun("Would add subreddit \(name)."))
    }
    let nextOrder = (subreddits.map(\.sortOrder).max() ?? -1) + 1
    let subreddit = Subreddit(name: name, sortOrder: nextOrder)
    context.insert(subreddit)
    try context.save()
    try heuristicsStore.syncGeneratedEvents(
      for: subreddit,
      context: context,
      defaultLeadTimeMinutes: defaultLeadTimeMinutes
    )
    return .success(
      data: .subreddit(SubredditDTO(subreddit, peakInfo: heuristicsStore.peakInfo(for: subreddit))))
  }

  func update(input: SubredditUpdateInput) throws -> CLIResponse {
    let subreddit = try findSubreddit(input.id)
    let updatedName = try input.name.map { try validatedName($0, current: subreddit) }
    if options.dryRun {
      return .success(data: .dryRun("Would update subreddit \(subreddit.name)."))
    }
    if let updatedName { subreddit.name = updatedName }
    if input.clearChecklist { subreddit.postingChecklist = nil }
    if let checklist = input.checklist { subreddit.postingChecklist = checklist }
    try heuristicsStore.syncGeneratedEvents(
      for: subreddit,
      context: context,
      defaultLeadTimeMinutes: defaultLeadTimeMinutes
    )
    try context.save()
    return .success(
      data: .subreddit(SubredditDTO(subreddit, peakInfo: heuristicsStore.peakInfo(for: subreddit))))
  }

  func delete(id: String) throws -> CLIResponse {
    let subreddit = try findSubreddit(id)
    if options.dryRun {
      return .success(data: .dryRun("Would delete subreddit \(subreddit.name)."))
    }
    let deletedId = subreddit.id.uuidString
    for event in subreddit.events {
      NotificationService().cancelNotifications(eventId: event.id.uuidString)
    }
    context.delete(subreddit)
    try context.save()
    return .success(data: .deleted(DeletedDTO(id: deletedId)))
  }

  func verify(name input: String) async throws -> CLIResponse {
    let name = try normalizedSubredditName(input)
    let verification = try await SubredditVerifier().verify(name: name)
    return .success(data: .subredditVerification(verification.dto))
  }

  func findSubreddit(_ input: String) throws -> Subreddit {
    let normalized = SubredditName.normalizedName(input) ?? input
    let subreddits = fetchSubreddits(matching: nil)
    if let subreddit = subreddits.first(where: {
      $0.id.uuidString == input || $0.name.caseInsensitiveCompare(normalized) == .orderedSame
    }) {
      return subreddit
    }
    throw CLIError.notFound("Subreddit not found: \(input)")
  }

  private func fetchSubreddits(matching query: String?) -> [Subreddit] {
    let descriptor = FetchDescriptor<Subreddit>(sortBy: [SortDescriptor(\.sortOrder)])
    return CLIFilter.items((try? context.fetch(descriptor)) ?? [], query: query) { subreddit in
      [subreddit.id.uuidString, subreddit.name, subreddit.postingChecklist ?? ""].joined(
        separator: " ")
    }
  }

  private func normalizedSubredditName(_ input: String) throws -> String {
    let normalized = SubredditName.normalize(input)
    guard case .success(let name) = normalized else {
      if case .failure(let error) = normalized { throw CLIError.validation(error.message) }
      throw CLIError.validation(SubredditName.ValidationError.empty.message)
    }
    return name
  }

  private func validatedName(_ input: String, current: Subreddit) throws -> String {
    let name = try normalizedSubredditName(input)
    let subreddits = fetchSubreddits(matching: nil)
    guard !subreddits.contains(where: {
      $0.id != current.id && $0.name.caseInsensitiveCompare(name) == .orderedSame
    }) else {
      throw CLIError.validation(SubredditName.ValidationError.duplicate.message)
    }
    return name
  }

  private var defaultLeadTimeMinutes: Int {
    UserDefaults.standard.object(forKey: SettingsKey.defaultLeadTimeMinutes) as? Int ?? 60
  }
}
