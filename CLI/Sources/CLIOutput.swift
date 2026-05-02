import Foundation

enum CLIFormat {
  static let encoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return encoder
  }()

  static let prettyEncoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    return encoder
  }()

  static func date(_ date: Date) -> String {
    ISO8601DateFormatter().string(from: date)
  }
}

enum CLIPrinter {
  static func print(_ response: CLIResponse, options: CLIOptions) {
    if options.json {
      let encoder = options.pretty ? CLIFormat.prettyEncoder : CLIFormat.encoder
      let data = (try? encoder.encode(response)) ?? Data()
      Swift.print(String(data: data, encoding: .utf8) ?? "{}")
    } else {
      Swift.print(humanSummary(response))
    }
  }

  static func printError(_ error: CLIError) {
    let response = CLIErrorResponse(
      ok: false, data: Optional<String>.none, warnings: [], errors: [error.message])
    let data = (try? CLIFormat.prettyEncoder.encode(response)) ?? Data()
    fputs((String(data: data, encoding: .utf8) ?? "{\"ok\":false}") + "\n", stderr)
  }

  private static func humanSummary(_ response: CLIResponse) -> String {
    guard response.ok else { return response.errors.joined(separator: "\n") }
    guard let data = response.data else { return "OK" }
    switch data {
    case .captures(let captures):
      return captures.map { "\($0.id) \($0.status) \($0.title ?? $0.text)" }.joined(separator: "\n")
    case .projects(let projects):
      return projects.map { "\($0.id) \($0.name)" }.joined(separator: "\n")
    case .project(let project): return "Created project \(project.name) (\(project.id))"
    case .subreddits(let subreddits):
      return subreddits.map { "\($0.id) \($0.name)" }.joined(separator: "\n")
    case .subreddit(let subreddit): return "Added subreddit \(subreddit.name) (\(subreddit.id))"
    case .peakPresets(let presets):
      return presets.map {
        "\($0.label): \($0.days.joined(separator: ",")) @ \($0.localHours.map(String.init).joined(separator: ","))"
      }.joined(separator: "\n")
    case .peakInfo(let info):
      return
        "\(info.subreddit.name): \(info.peak.days.joined(separator: ",")) @ local \(info.peak.hoursLocal.map(String.init).joined(separator: ","))"
    case .dryRun(let message): return message
    }
  }
}

struct CLIErrorResponse: Encodable {
  let ok: Bool
  let data: String?
  let warnings: [String]
  let errors: [String]
}

enum CLIError: Error {
  case usage(String)
  case validation(String)
  case notFound(String)
  case runtime(String)

  var message: String {
    switch self {
    case .usage(let value), .validation(let value), .notFound(let value), .runtime(let value):
      return value
    }
  }

  var exitCode: Int {
    switch self {
    case .usage: 64
    case .validation: 65
    case .notFound: 66
    case .runtime: 1
    }
  }
}

enum CLIHelp {
  static let root = """
    Usage: redditreminder [--json] [--pretty] [--dry-run] [--store PATH] <domain> <command>

    Domains: captures, projects, subreddits, peaks
    """

  static func domain(_ domain: String) -> String {
    switch domain {
    case "captures": return "Usage: redditreminder captures list|search [--query TEXT]"
    case "projects": return "Usage: redditreminder projects list|search|create"
    case "subreddits": return "Usage: redditreminder subreddits list|search|add"
    case "peaks": return "Usage: redditreminder peaks presets|get|set|reset"
    default: return root
    }
  }
}
