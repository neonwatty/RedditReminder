import Foundation
import SwiftData

@MainActor
final class CLIRunner {
  private let options: CLIOptions
  private let container: ModelContainer
  private let context: ModelContext
  private let heuristicsStore: HeuristicsStore

  init(options: CLIOptions) throws {
    self.options = options
    let schema = Schema([Project.self, Capture.self, Subreddit.self, SubredditEvent.self])
    let configuration = ModelConfiguration(
      "default",
      schema: schema,
      url: CLIStore.storeURL(from: options.storePath),
      cloudKitDatabase: .none
    )
    container = try ModelContainer(for: schema, configurations: configuration)
    context = ModelContext(container)
    heuristicsStore = HeuristicsStore()
  }

  func run(command: CLICommand) throws -> CLIResponse {
    switch command {
    case .capturesList(let query):
      return .success(data: .captures(fetchCaptures(matching: query).map(CaptureDTO.init)))
    case .projectsList(let query):
      return .success(data: .projects(fetchProjects(matching: query).map(ProjectDTO.init)))
    case .projectCreate(let name):
      return try createProject(name: name)
    case .subredditsList(let query):
      let subreddits = fetchSubreddits(matching: query).map {
        SubredditDTO($0, peakInfo: heuristicsStore.peakInfo(for: $0))
      }
      return .success(data: .subreddits(subreddits))
    case .subredditAdd(let name):
      return try addSubreddit(name: name)
    case .peaksPresets:
      return .success(data: .peakPresets(SubredditPeakSelection.presets.map(PeakPresetDTO.init)))
    case .peaksGet(let subreddit):
      return try peakInfo(for: subreddit)
    case .peaksSet(let subreddit, let days, let hours, let timeZone):
      return try setPeakInfo(for: subreddit, days: days, hours: hours, timeZone: timeZone)
    case .peaksReset(let subreddit):
      return try resetPeakInfo(for: subreddit)
    }
  }

  private func fetchCaptures(matching query: String?) -> [Capture] {
    let descriptor = FetchDescriptor<Capture>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
    )
    let captures = (try? context.fetch(descriptor)) ?? []
    return filter(captures, query: query) { capture in
      [
        capture.id.uuidString,
        capture.title ?? "",
        capture.text,
        capture.notes ?? "",
        capture.project?.name ?? "",
        capture.subreddits.map(\.name).joined(separator: " "),
      ].joined(separator: " ")
    }
  }

  private func fetchProjects(matching query: String?) -> [Project] {
    let descriptor = FetchDescriptor<Project>(sortBy: [SortDescriptor(\.name)])
    return filter((try? context.fetch(descriptor)) ?? [], query: query) { project in
      [project.id.uuidString, project.name, project.projectDescription ?? ""].joined(separator: " ")
    }
  }

  private func fetchSubreddits(matching query: String?) -> [Subreddit] {
    let descriptor = FetchDescriptor<Subreddit>(sortBy: [SortDescriptor(\.sortOrder)])
    return filter((try? context.fetch(descriptor)) ?? [], query: query) { subreddit in
      [subreddit.id.uuidString, subreddit.name, subreddit.postingChecklist ?? ""].joined(
        separator: " ")
    }
  }

  private func filter<T>(_ items: [T], query: String?, searchableText: (T) -> String) -> [T] {
    guard let normalized = query?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
      !normalized.isEmpty
    else { return items }
    return items.filter { searchableText($0).lowercased().contains(normalized) }
  }

  private func createProject(name: String) throws -> CLIResponse {
    let projects = fetchProjects(matching: nil)
    guard let trimmed = ProjectPersistenceActions.normalizedName(name) else {
      throw CLIError.validation("Project name cannot be empty.")
    }
    guard ProjectPersistenceActions.isNameAvailable(trimmed, projects: projects) else {
      throw CLIError.validation("Project already exists: \(trimmed)")
    }
    if options.dryRun {
      return .success(data: .dryRun("Would create project \(trimmed)."))
    }
    let project = Project(name: trimmed)
    context.insert(project)
    try context.save()
    return .success(data: .project(ProjectDTO(project)))
  }

  private func addSubreddit(name input: String) throws -> CLIResponse {
    let subreddits = fetchSubreddits(matching: nil)
    let normalized = SubredditName.normalize(input)
    guard case .success(let name) = normalized else {
      if case .failure(let error) = normalized { throw CLIError.validation(error.message) }
      throw CLIError.validation(SubredditName.ValidationError.empty.message)
    }
    guard !subreddits.contains(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame })
    else {
      throw CLIError.validation(SubredditName.ValidationError.duplicate.message)
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

  private func peakInfo(for input: String) throws -> CLIResponse {
    let subreddit = try findSubreddit(input)
    return .success(
      data: .peakInfo(
        PeakInfoDTO(subreddit: subreddit, peakInfo: heuristicsStore.peakInfo(for: subreddit))))
  }

  private func setPeakInfo(
    for input: String,
    days: [String],
    hours: [Int],
    timeZone identifier: String?
  ) throws -> CLIResponse {
    let subreddit = try findSubreddit(input)
    let validDays = Set(SubredditPeakSelection.dayKeys)
    guard !days.isEmpty, days.allSatisfy({ validDays.contains($0) }) else {
      throw CLIError.validation("Days must use mon,tue,wed,thu,fri,sat,sun.")
    }
    guard !hours.isEmpty else { throw CLIError.validation("At least one hour is required.") }

    let timeZone = identifier.flatMap(TimeZone.init(identifier:)) ?? .current
    if identifier != nil, TimeZone(identifier: identifier!) == nil {
      throw CLIError.validation("Unknown timezone: \(identifier!)")
    }
    let appliedHours = hours.map { SubredditPeakSelection.localHourToUtc($0, timeZone: timeZone) }
      .sorted()
    if options.dryRun {
      return .success(
        data: .dryRun(
          "Would set \(subreddit.name) peak days \(days.joined(separator: ",")) and local hours \(hours.map(String.init).joined(separator: ","))."
        ))
    }

    subreddit.peakDaysOverride = days
    subreddit.peakHoursUtcOverride = appliedHours
    try heuristicsStore.syncGeneratedEvents(
      for: subreddit,
      context: context,
      defaultLeadTimeMinutes: defaultLeadTimeMinutes
    )
    try context.save()
    return .success(
      data: .peakInfo(
        PeakInfoDTO(subreddit: subreddit, peakInfo: heuristicsStore.peakInfo(for: subreddit))))
  }

  private func resetPeakInfo(for input: String) throws -> CLIResponse {
    let subreddit = try findSubreddit(input)
    if options.dryRun {
      return .success(data: .dryRun("Would reset peak overrides for \(subreddit.name)."))
    }
    subreddit.peakDaysOverride = nil
    subreddit.peakHoursUtcOverride = nil
    try heuristicsStore.syncGeneratedEvents(
      for: subreddit,
      context: context,
      defaultLeadTimeMinutes: defaultLeadTimeMinutes
    )
    try context.save()
    return .success(
      data: .peakInfo(
        PeakInfoDTO(subreddit: subreddit, peakInfo: heuristicsStore.peakInfo(for: subreddit))))
  }

  private func findSubreddit(_ input: String) throws -> Subreddit {
    let normalized = SubredditName.normalizedName(input) ?? input
    let subreddits = fetchSubreddits(matching: nil)
    if let subreddit = subreddits.first(where: {
      $0.id.uuidString == input || $0.name.caseInsensitiveCompare(normalized) == .orderedSame
    }) {
      return subreddit
    }
    throw CLIError.notFound("Subreddit not found: \(input)")
  }

  private var defaultLeadTimeMinutes: Int {
    UserDefaults.standard.object(forKey: SettingsKey.defaultLeadTimeMinutes) as? Int ?? 60
  }
}

enum CLIStore {
  static func storeURL(from path: String?) -> URL {
    if let path, !path.isEmpty {
      return URL(fileURLWithPath: NSString(string: path).expandingTildeInPath)
    }
    return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("default.store")
  }
}
