import Foundation

extension CLIArgumentParser {
  mutating func consumeEventListInput(queryRequired: Bool) throws -> EventListInput {
    let query =
      queryRequired
      ? try consumeRequiredValue(for: "--query")
      : consumeOptionalValue(for: "--query")
    let from = try consumeOptionalValue(for: "--from").map {
      try parsedDate($0, label: "--from")
    }
    let to = try consumeOptionalValue(for: "--to").map {
      try parsedDate($0, label: "--to")
    }
    let input = try EventListInput(
      query: normalizedOptional(query),
      subreddit: normalizedOptional(consumeOptionalValue(for: "--subreddit")),
      from: from,
      to: to,
      generated: generatedFilter(),
      active: activeFilter()
    )
    return input
  }

  mutating func consumeEventCreateInput() throws -> EventCreateInput {
    let subreddit = try consumeRequiredValue(for: "--subreddit")
    let date = try parsedDate(try consumeRequiredValue(for: "--date"), label: "--date")
    let leadMinutes = try consumeOptionalValue(for: "--lead-minutes").map {
      try parsedNonNegativeInt($0, label: "--lead-minutes")
    }
    return EventCreateInput(
      name: normalizedOptional(consumeOptionalValue(for: "--name")),
      subreddit: subreddit,
      date: date,
      leadMinutes: leadMinutes
    )
  }

  mutating func consumeEventUpdateInput() throws -> EventUpdateInput {
    let id = try consumeRequiredArgument(label: "event id")
    let leadMinutes = try consumeOptionalValue(for: "--lead-minutes").map {
      try parsedNonNegativeInt($0, label: "--lead-minutes")
    }
    let active = try activeMutation()
    let date = try consumeOptionalValue(for: "--date").map {
      try parsedDate($0, label: "--date")
    }
    let input = EventUpdateInput(
      id: id,
      name: normalizedOptional(consumeOptionalValue(for: "--name")),
      date: date,
      leadMinutes: leadMinutes,
      active: active
    )
    guard input.hasChanges else {
      throw CLIError.usage("Event update requires at least one field flag.")
    }
    return input
  }

  private mutating func generatedFilter() throws -> Bool? {
    let manual = consumeFlag("--manual")
    let generated = consumeFlag("--generated")
    guard !(manual && generated) else {
      throw CLIError.usage("Use only one of --manual or --generated.")
    }
    if manual { return false }
    if generated { return true }
    return nil
  }

  private mutating func activeFilter() throws -> Bool? {
    let active = consumeFlag("--active")
    let inactive = consumeFlag("--inactive")
    guard !(active && inactive) else {
      throw CLIError.usage("Use only one of --active or --inactive.")
    }
    if active { return true }
    if inactive { return false }
    return nil
  }

  private mutating func activeMutation() throws -> Bool? {
    let activate = consumeFlag("--activate")
    let deactivate = consumeFlag("--deactivate")
    guard !(activate && deactivate) else {
      throw CLIError.usage("Use only one of --activate or --deactivate.")
    }
    if activate { return true }
    if deactivate { return false }
    return nil
  }
}
