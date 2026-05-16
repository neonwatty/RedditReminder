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

  func run(command: CLICommand) async throws -> CLIResponse {
    switch command {
    case .agentBootstrap:
      return CLIAgentBootstrap.show()
    case .agentValidate(let input):
      return CLIAgentValidator.validate(input: input)
    case .agentDryRun(let input):
      return try await CLIAgentDryRunner.dryRun(input: input, options: options)
    case .capturesList(let query):
      return .success(data: .captures(fetchCaptures(matching: query).map(CaptureDTO.init)))
    case .captureCreate(let input):
      return try CLICaptureCreator(options: options, context: context).create(input: input)
    case .captureUpdate(let input):
      return try CLICaptureLifecycle(options: options, context: context).update(input: input)
    case .captureDelete(let id):
      return try CLICaptureLifecycle(options: options, context: context).delete(id: id)
    case .captureMarkPosted(let input):
      return try CLICaptureLifecycle(options: options, context: context).markPosted(input: input)
    case .captureMarkQueued(let input):
      return try CLICaptureLifecycle(options: options, context: context).markQueued(input: input)
    case .eventsList(let input):
      return try CLIEventManager(options: options, context: context).list(input: input)
    case .eventCreate(let input):
      return try CLIEventManager(options: options, context: context).create(input: input)
    case .eventUpdate(let input):
      return try CLIEventManager(options: options, context: context).update(input: input)
    case .eventDelete(let id):
      return try CLIEventManager(options: options, context: context).delete(id: id)
    case .projectsList(let query):
      return CLIProjectManager(options: options, context: context).list(query: query)
    case .projectCreate(let name):
      return try CLIProjectManager(options: options, context: context).create(name: name)
    case .projectUpdate(let input):
      return try CLIProjectManager(options: options, context: context).update(input: input)
    case .projectDelete(let id):
      return try CLIProjectManager(options: options, context: context).delete(id: id)
    case .subredditsList(let query):
      return subredditManager.list(query: query)
    case .subredditAdd(let name, let verify):
      return try await subredditManager.add(name: name, verify: verify)
    case .subredditUpdate(let input):
      return try subredditManager.update(input: input)
    case .subredditDelete(let id):
      return try subredditManager.delete(id: id)
    case .subredditVerify(let name):
      return try await subredditManager.verify(name: name)
    case .peaksPresets:
      return .success(data: .peakPresets(SubredditPeakSelection.presets.map(PeakPresetDTO.init)))
    case .peaksGet(let subreddit):
      return try peakInfo(for: subreddit)
    case .peaksSet(let subreddit, let days, let hours, let timeZone):
      return try setPeakInfo(for: subreddit, days: days, hours: hours, timeZone: timeZone)
    case .peaksReset(let subreddit):
      return try resetPeakInfo(for: subreddit)
    case .searchAll(let input):
      return discoveryManager.search(input: input)
    case .contextShow(let input):
      return discoveryManager.showContext(input: input)
    case .commandsList:
      return CLICommandCatalog.list()
    case .commandsShow(let id):
      return try CLICommandCatalog.show(id: id)
    case .recipesList:
      return CLIRecipeCatalog.list()
    case .recipesSearch(let query):
      return CLIRecipeCatalog.search(query: query)
    case .recipesShow(let id):
      return try CLIRecipeCatalog.show(id: id)
    }
  }

  private func fetchCaptures(matching query: String?) -> [Capture] {
    let descriptor = FetchDescriptor<Capture>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
    )
    let captures = (try? context.fetch(descriptor)) ?? []
    return CLIFilter.items(captures, query: query) { capture in
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

  private func peakInfo(for input: String) throws -> CLIResponse {
    let subreddit = try subredditManager.findSubreddit(input)
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
    let subreddit = try subredditManager.findSubreddit(input)
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
    let subreddit = try subredditManager.findSubreddit(input)
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

  private var defaultLeadTimeMinutes: Int {
    UserDefaults.standard.object(forKey: SettingsKey.defaultLeadTimeMinutes) as? Int ?? 60
  }

  private var subredditManager: CLISubredditManager {
    CLISubredditManager(options: options, context: context, heuristicsStore: heuristicsStore)
  }

  private var discoveryManager: CLIDiscoveryManager {
    CLIDiscoveryManager(context: context, heuristicsStore: heuristicsStore)
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

  static func mediaRootURL(from path: String?) -> URL? {
    guard let path, !path.isEmpty else { return nil }
    return URL(fileURLWithPath: NSString(string: path).expandingTildeInPath)
      .deletingLastPathComponent()
      .appendingPathComponent("media")
  }
}
