import Foundation

extension CLIArgumentParser {
  mutating func consumeProjectUpdateInput() throws -> ProjectUpdateInput {
    let id = try consumeRequiredArgument(label: "project id or name")
    let input = ProjectUpdateInput(
      id: id,
      name: normalizedOptional(consumeOptionalValue(for: "--name")),
      description: normalizedOptional(consumeOptionalValue(for: "--description")),
      clearDescription: consumeFlag("--clear-description"),
      color: normalizedOptional(consumeOptionalValue(for: "--color")),
      clearColor: consumeFlag("--clear-color"),
      archive: consumeFlag("--archive"),
      unarchive: consumeFlag("--unarchive")
    )
    guard input.hasChanges else {
      throw CLIError.usage("Project update requires at least one change.")
    }
    guard !(input.description != nil && input.clearDescription) else {
      throw CLIError.usage("Use either --description or --clear-description, not both.")
    }
    guard !(input.color != nil && input.clearColor) else {
      throw CLIError.usage("Use either --color or --clear-color, not both.")
    }
    guard !(input.archive && input.unarchive) else {
      throw CLIError.usage("Use either --archive or --unarchive, not both.")
    }
    return input
  }

  mutating func consumeSubredditUpdateInput() throws -> SubredditUpdateInput {
    let id = try consumeRequiredArgument(label: "subreddit id or name")
    let input = SubredditUpdateInput(
      id: id,
      name: normalizedOptional(consumeOptionalValue(for: "--name")),
      checklist: normalizedOptional(consumeOptionalValue(for: "--checklist")),
      clearChecklist: consumeFlag("--clear-checklist")
    )
    guard input.hasChanges else {
      throw CLIError.usage("Subreddit update requires at least one change.")
    }
    guard !(input.checklist != nil && input.clearChecklist) else {
      throw CLIError.usage("Use either --checklist or --clear-checklist, not both.")
    }
    return input
  }
}
