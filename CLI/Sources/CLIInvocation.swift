import Foundation

struct CLIInvocation {
  let options: CLIOptions
  let command: CLICommand

  init(arguments: [String]) throws {
    var parser = CLIArgumentParser(arguments)
    let options = try parser.consumeGlobalOptions()
    guard let domain = parser.consumeValue() else { throw CLIError.usage(CLIHelp.root) }
    guard let action = parser.consumeValue() else { throw CLIError.usage(CLIHelp.domain(domain)) }
    command = try CLICommand(domain: domain, action: action, parser: &parser)
    try parser.rejectRemaining()
    self.options = options
  }
}

struct CLIOptions {
  var json = false
  var pretty = false
  var dryRun = false
  var storePath: String?
}

enum CLICommand {
  case capturesList(query: String?)
  case captureCreate(CaptureCreateInput)
  case captureUpdate(CaptureUpdateInput)
  case captureDelete(id: String)
  case captureMarkPosted(id: String, url: String?)
  case captureMarkQueued(id: String)
  case projectsList(query: String?)
  case projectCreate(name: String)
  case subredditsList(query: String?)
  case subredditAdd(name: String)
  case peaksPresets
  case peaksGet(subreddit: String)
  case peaksSet(subreddit: String, days: [String], hours: [Int], timeZone: String?)
  case peaksReset(subreddit: String)

  init(domain: String, action: String, parser: inout CLIArgumentParser) throws {
    switch (domain, action) {
    case ("captures", "list"):
      self = .capturesList(query: parser.consumeOptionalValue(for: "--query"))
    case ("captures", "search"):
      self = .capturesList(query: try parser.consumeRequiredValue(for: "--query"))
    case ("captures", "create"):
      self = .captureCreate(try parser.consumeCaptureCreateInput())
    case ("captures", "update"):
      self = .captureUpdate(try parser.consumeCaptureUpdateInput())
    case ("captures", "delete"):
      self = .captureDelete(id: try parser.consumeRequiredArgument(label: "capture id"))
    case ("captures", "mark-posted"):
      let id = try parser.consumeRequiredArgument(label: "capture id")
      self = .captureMarkPosted(id: id, url: parser.consumeOptionalValue(for: "--url"))
    case ("captures", "mark-queued"):
      self = .captureMarkQueued(id: try parser.consumeRequiredArgument(label: "capture id"))
    case ("projects", "list"):
      self = .projectsList(query: parser.consumeOptionalValue(for: "--query"))
    case ("projects", "search"):
      self = .projectsList(query: try parser.consumeRequiredValue(for: "--query"))
    case ("projects", "create"):
      self = .projectCreate(name: try parser.consumeTrailingName(label: "project name"))
    case ("subreddits", "list"):
      self = .subredditsList(query: parser.consumeOptionalValue(for: "--query"))
    case ("subreddits", "search"):
      self = .subredditsList(query: try parser.consumeRequiredValue(for: "--query"))
    case ("subreddits", "add"):
      self = .subredditAdd(name: try parser.consumeTrailingName(label: "subreddit name"))
    case ("peaks", "presets"):
      self = .peaksPresets
    case ("peaks", "get"):
      self = .peaksGet(subreddit: try parser.consumeSubredditArgument())
    case ("peaks", "set"):
      let subreddit = try parser.consumeSubredditArgument()
      let days = try parser.consumeCSV(for: "--days")
      let hours = try parser.consumeHours(for: "--hours")
      let timeZone = parser.consumeOptionalValue(for: "--timezone")
      self = .peaksSet(subreddit: subreddit, days: days, hours: hours, timeZone: timeZone)
    case ("peaks", "reset"):
      self = .peaksReset(subreddit: try parser.consumeSubredditArgument())
    default:
      throw CLIError.usage(CLIHelp.domain(domain))
    }
  }
}

struct CLIArgumentParser {
  private var arguments: [String]

  init(_ arguments: [String]) {
    self.arguments = arguments
  }

  mutating func consumeGlobalOptions() throws -> CLIOptions {
    var options = CLIOptions()
    var index = 0
    while index < arguments.count {
      let argument = arguments[index]
      switch argument {
      case "--json":
        options.json = true
        arguments.remove(at: index)
      case "--pretty":
        options.pretty = true
        options.json = true
        arguments.remove(at: index)
      case "--dry-run":
        options.dryRun = true
        arguments.remove(at: index)
      case "--store":
        guard arguments.indices.contains(index + 1) else {
          throw CLIError.usage("Missing value for --store.")
        }
        options.storePath = arguments[index + 1]
        arguments.removeSubrange(index...(index + 1))
      default:
        index += 1
      }
    }
    return options
  }

  mutating func consumeValue() -> String? {
    guard !arguments.isEmpty else { return nil }
    return arguments.removeFirst()
  }

  mutating func consumeOptionalValue(for flag: String) -> String? {
    guard let index = arguments.firstIndex(of: flag),
      arguments.indices.contains(index + 1)
    else { return nil }
    let value = arguments[index + 1]
    arguments.removeSubrange(index...(index + 1))
    return value
  }

  mutating func consumeRepeatedValues(for flag: String) -> [String] {
    var values: [String] = []
    while let index = arguments.firstIndex(of: flag),
      arguments.indices.contains(index + 1)
    {
      values.append(arguments[index + 1])
      arguments.removeSubrange(index...(index + 1))
    }
    return values
  }

  mutating func consumeRequiredValue(for flag: String) throws -> String {
    guard let value = consumeOptionalValue(for: flag), !value.isEmpty else {
      throw CLIError.usage("Missing value for \(flag).")
    }
    return value
  }

  mutating func consumeTrailingName(label: String) throws -> String {
    let value = arguments.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    arguments.removeAll()
    guard !value.isEmpty else { throw CLIError.usage("Missing \(label).") }
    return value
  }

  mutating func consumeSubredditArgument() throws -> String {
    if let value = consumeOptionalValue(for: "--subreddit") { return value }
    guard let value = consumeValue() else { throw CLIError.usage("Missing subreddit.") }
    return value
  }

  mutating func consumeRequiredArgument(label: String) throws -> String {
    guard let value = consumeValue(), !value.isEmpty else {
      throw CLIError.usage("Missing \(label).")
    }
    return value
  }

  mutating func consumeCSV(for flag: String) throws -> [String] {
    try consumeRequiredValue(for: flag)
      .split(separator: ",")
      .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
      .filter { !$0.isEmpty }
  }

  mutating func consumeHours(for flag: String) throws -> [Int] {
    let values = try consumeCSV(for: flag)
    let hours = try values.map { value in
      guard let hour = Int(value), (0...23).contains(hour) else {
        throw CLIError.usage("Hours must be comma-separated integers from 0 through 23.")
      }
      return hour
    }
    return Array(Set(hours)).sorted()
  }

  mutating func consumeCaptureCreateInput() throws -> CaptureCreateInput {
    let title = consumeOptionalValue(for: "--title")
    let textFlag = consumeOptionalValue(for: "--text")
    let notes = consumeOptionalValue(for: "--notes")
    let project = consumeOptionalValue(for: "--project")
    let due = consumeOptionalValue(for: "--due")
    let links =
      consumeRepeatedValues(for: "--link") + splitCSV(consumeOptionalValue(for: "--links"))
    let subreddits =
      consumeRepeatedValues(for: "--subreddit")
      + splitCSV(consumeOptionalValue(for: "--subreddits"))
    let mediaPaths =
      consumeRepeatedValues(for: "--media") + splitCSV(consumeOptionalValue(for: "--media-paths"))
    if let unexpected = arguments.first(where: { $0.hasPrefix("--") }) {
      throw CLIError.usage("Unexpected capture create option: \(unexpected)")
    }
    let trailingText = arguments.joined(separator: " ").trimmingCharacters(
      in: .whitespacesAndNewlines)
    arguments.removeAll()

    let input = CaptureCreateInput(
      title: normalizedOptional(title),
      text: (textFlag ?? trailingText).trimmingCharacters(in: .whitespacesAndNewlines),
      notes: normalizedOptional(notes),
      links: links,
      project: normalizedOptional(project),
      subreddits: subreddits,
      mediaPaths: mediaPaths,
      due: normalizedOptional(due)
    )
    guard input.title != nil || !input.text.isEmpty else {
      throw CLIError.usage("Capture create requires --text, --title, or trailing text.")
    }
    return input
  }

  mutating func consumeCaptureUpdateInput() throws -> CaptureUpdateInput {
    let id = try consumeRequiredArgument(label: "capture id")
    let title = consumeOptionalValue(for: "--title")
    let text = consumeOptionalValue(for: "--text")
    let notes = consumeOptionalValue(for: "--notes")
    let project = consumeOptionalValue(for: "--project")
    let links =
      consumeRepeatedValues(for: "--link") + splitCSV(consumeOptionalValue(for: "--links"))
    let subreddits =
      consumeRepeatedValues(for: "--subreddit")
      + splitCSV(consumeOptionalValue(for: "--subreddits"))
    let mediaPaths =
      consumeRepeatedValues(for: "--media")
      + splitCSV(consumeOptionalValue(for: "--media-paths"))
    let removedMediaRefs =
      consumeRepeatedValues(for: "--remove-media")
      + splitCSV(consumeOptionalValue(for: "--remove-media-refs"))

    let input = CaptureUpdateInput(
      id: id,
      title: normalizedOptional(title),
      clearTitle: consumeFlag("--clear-title"),
      text: normalizedOptional(text),
      notes: normalizedOptional(notes),
      clearNotes: consumeFlag("--clear-notes"),
      links: links.isEmpty ? nil : links,
      clearLinks: consumeFlag("--clear-links"),
      project: normalizedOptional(project),
      clearProject: consumeFlag("--clear-project"),
      subreddits: subreddits.isEmpty ? nil : subreddits,
      clearSubreddits: consumeFlag("--clear-subreddits"),
      mediaPaths: mediaPaths,
      removedMediaRefs: removedMediaRefs,
      clearMedia: consumeFlag("--clear-media")
    )
    guard input.hasChanges else {
      throw CLIError.usage("Capture update requires at least one field flag.")
    }
    return input
  }

  private func splitCSV(_ value: String?) -> [String] {
    value?
      .split(separator: ",")
      .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty } ?? []
  }

  private func normalizedOptional(_ value: String?) -> String? {
    let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return trimmed.isEmpty ? nil : trimmed
  }

  private mutating func consumeFlag(_ flag: String) -> Bool {
    guard let index = arguments.firstIndex(of: flag) else { return false }
    arguments.remove(at: index)
    return true
  }

  func rejectRemaining() throws {
    guard arguments.isEmpty else {
      throw CLIError.usage("Unexpected arguments: \(arguments.joined(separator: " "))")
    }
  }
}
