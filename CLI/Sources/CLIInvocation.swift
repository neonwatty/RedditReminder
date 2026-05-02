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

  func rejectRemaining() throws {
    guard arguments.isEmpty else {
      throw CLIError.usage("Unexpected arguments: \(arguments.joined(separator: " "))")
    }
  }
}
