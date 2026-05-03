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
    case .captureCreated(let created):
      return "Created capture \(created.capture.id)"
    case .capture(let capture):
      return "\(capture.id) \(capture.status) \(capture.title ?? capture.text)"
    case .deleted(let deleted):
      return "Deleted \(deleted.id)"
    case .events(let events):
      return events.map { "\($0.id) \($0.name)" }.joined(separator: "\n")
    case .event(let event):
      return "\(event.id) \(event.name)"
    case .projects(let projects):
      return projects.map { "\($0.id) \($0.name)" }.joined(separator: "\n")
    case .project(let project): return "Project \(project.name) (\(project.id))"
    case .subreddits(let subreddits):
      return subreddits.map { "\($0.id) \($0.name)" }.joined(separator: "\n")
    case .subreddit(let subreddit): return "Added subreddit \(subreddit.name) (\(subreddit.id))"
    case .subredditVerification(let verification):
      return verification.exists
        ? "Verified \(verification.name)"
        : "Subreddit not found: \(verification.name)"
    case .peakPresets(let presets):
      return presets.map {
        "\($0.label): \($0.days.joined(separator: ",")) @ \($0.localHours.map(String.init).joined(separator: ","))"
      }.joined(separator: "\n")
    case .peakInfo(let info):
      return
        "\(info.subreddit.name): \(info.peak.days.joined(separator: ",")) @ local \(info.peak.hoursLocal.map(String.init).joined(separator: ","))"
    case .searchResults(let results):
      return results.map { "\($0.kind) \($0.id) \($0.title)" }.joined(separator: "\n")
    case .context(let context):
      return
        "Context: \(context.counts.capturesQueued) queued captures, \(context.counts.subreddits) subreddits, \(context.counts.eventsActive) active events"
    case .commandReferences(let commands):
      return commands.map { "\($0.id) - \($0.summary)" }.joined(separator: "\n")
    case .commandReference(let command):
      return "\(command.id) - \(command.summary)"
    case .recipeReferences(let recipes):
      return recipes.map { "\($0.id) - \($0.summary)" }.joined(separator: "\n")
    case .recipeReference(let recipe):
      return "\(recipe.id) - \(recipe.summary)"
    case .agentBootstrap(let bootstrap):
      return "\(bootstrap.toolName) agent bootstrap - \(bootstrap.summary)"
    case .agentValidation(let validation):
      return validation.valid
        ? "Valid command: \(validation.commandId ?? validation.normalizedCommand.joined(separator: " "))"
        : "Invalid command: \(validation.errors.joined(separator: "; "))"
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

    Domains: agent, captures, events, projects, subreddits, peaks, search, context, commands, recipes
    """

  static func domain(_ domain: String) -> String {
    switch domain {
    case "agent": return "Usage: redditreminder agent bootstrap|validate"
    case "captures":
      return
        "Usage: redditreminder captures list|search|create|update|delete|mark-posted|mark-queued"
    case "events": return "Usage: redditreminder events list|search|create|update|delete"
    case "projects": return "Usage: redditreminder projects list|search|create|update|delete"
    case "subreddits": return "Usage: redditreminder subreddits list|search|add|update|delete|verify"
    case "peaks": return "Usage: redditreminder peaks presets|get|set|reset"
    case "search": return "Usage: redditreminder search all --query TEXT [--limit N]"
    case "context": return "Usage: redditreminder context show [--limit N]"
    case "commands": return "Usage: redditreminder commands list|show"
    case "recipes": return "Usage: redditreminder recipes list|search|show"
    default: return root
    }
  }
}
