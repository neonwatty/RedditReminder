import Foundation

enum CLICommandCatalog {
  static func list() -> CLIResponse {
    .success(data: .commandReferences(commands))
  }

  static func show(id input: String) throws -> CLIResponse {
    let normalized = input.lowercased()
    guard let command = commands.first(where: { $0.id == normalized }) else {
      throw CLIError.notFound("Command not found: \(input)")
    }
    return .success(data: .commandReference(command))
  }

  static let commands: [CommandReferenceDTO] =
    discoveryCommands
    + captureCommands
    + eventCommands
    + projectCommands
    + subredditCommands
    + peakCommands

  static let discoveryCommands: [CommandReferenceDTO] = [
    command(
      "context.show", "context", "show",
      "Return a compact workspace snapshot for agent planning.",
      flags: [flag("--limit", "N", "Maximum items per collection. Defaults to 20.")],
      examples: ["redditreminder --json context show --limit 5"],
      output: output("context", "Counts, projects, subreddits, queued captures, events, presets.")
    ),
    command(
      "search.all", "search", "all",
      "Search captures, events, projects, subreddits, and peak presets.",
      flags: [
        flag("--query", "TEXT", "Search text.", required: true),
        flag("--limit", "N", "Maximum results. Defaults to 20."),
      ],
      examples: ["redditreminder --json search all --query launch --limit 10"],
      output: output("searchResults", "Array of typed search hits.")
    ),
    command(
      "commands.list", "commands", "list",
      "Return metadata for every CLI command.",
      examples: ["redditreminder --json commands list"],
      output: output("commandReferences", "Array of command reference objects.")
    ),
    command(
      "commands.show", "commands", "show",
      "Return metadata for one CLI command.",
      positionals: [arg("id", "Command id, for example captures.create.")],
      examples: ["redditreminder --json commands show captures.create"],
      output: output("commandReference", "One command reference object.")
    ),
    command(
      "recipes.list", "recipes", "list",
      "Return agent workflow recipes.",
      examples: ["redditreminder --json recipes list"],
      output: output("recipeReferences", "Array of recipe reference objects.")
    ),
    command(
      "recipes.search", "recipes", "search",
      "Search agent workflow recipes by intent text.",
      flags: [flag("--query", "TEXT", "Search text.", required: true)],
      examples: ["redditreminder --json recipes search --query media"],
      output: output("recipeReferences", "Array of matching recipe reference objects.")
    ),
    command(
      "recipes.show", "recipes", "show",
      "Return one agent workflow recipe.",
      positionals: [arg("id", "Recipe id, for example posting.create-with-media.")],
      examples: ["redditreminder --json recipes show posting.create-with-media"],
      output: output("recipeReference", "One recipe reference object.")
    ),
  ]

  static func command(
    _ id: String,
    _ domain: String,
    _ command: String,
    _ summary: String,
    positionals: [CommandArgumentDTO] = [],
    flags: [CommandFlagDTO] = [],
    examples: [String],
    output: CommandOutputDTO
  ) -> CommandReferenceDTO {
    CommandReferenceDTO(
      id: id,
      domain: domain,
      command: command,
      summary: summary,
      positionals: positionals,
      flags: flags,
      examples: examples,
      output: output)
  }

  static func arg(_ name: String, _ summary: String, required: Bool = true)
    -> CommandArgumentDTO
  {
    CommandArgumentDTO(name: name, required: required, summary: summary)
  }

  static func flag(
    _ name: String,
    _ value: String?,
    _ summary: String,
    required: Bool = false,
    repeatable: Bool = false
  ) -> CommandFlagDTO {
    CommandFlagDTO(
      name: name,
      value: value,
      required: required,
      repeatable: repeatable,
      summary: summary)
  }

  static func output(_ data: String, _ summary: String) -> CommandOutputDTO {
    CommandOutputDTO(data: data, summary: summary)
  }

  static func eventListFlags() -> [CommandFlagDTO] {
    [
      flag("--subreddit", "NAME_OR_ID", "Filter by subreddit."),
      flag("--from", "ISO8601", "Filter one-off dates at or after this date."),
      flag("--to", "ISO8601", "Filter one-off dates at or before this date."),
      flag("--manual", nil, "Only manual events."),
      flag("--generated", nil, "Only generated peak events."),
      flag("--active", nil, "Only active events."),
      flag("--inactive", nil, "Only inactive events."),
    ]
  }
}
