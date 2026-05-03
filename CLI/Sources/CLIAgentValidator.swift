import Foundation

enum CLIAgentValidator {
  static func validate(input: AgentValidateInput) -> CLIResponse {
    let normalized = normalizedCommand(input.command)
    let result = validationResult(for: normalized)
    return .success(data: .agentValidation(result))
  }

  static func normalizedCommand(_ command: [String]) -> [String] {
    var tokens = command
    if let first = tokens.first,
      first == "redditreminder" || first.hasSuffix("/redditreminder")
    {
      tokens.removeFirst()
    }
    var output: [String] = []
    var index = 0
    while index < tokens.count {
      switch tokens[index] {
      case "--json", "--pretty", "--dry-run":
        index += 1
      case "--store":
        index += tokens.indices.contains(index + 1) ? 2 : 1
      default:
        output.append(tokens[index])
        index += 1
      }
    }
    return output
  }

  static func validationResult(for tokens: [String]) -> AgentValidationDTO {
    guard tokens.count >= 2 else {
      return result(tokens, nil, nil, ["Expected <domain> <command>."], [])
    }
    let commandId = "\(tokens[0]).\(tokens[1])"
    guard let command = CLICommandCatalog.commands.first(where: { $0.id == commandId }) else {
      return result(tokens, commandId, nil, ["Unknown command: \(commandId)."], [])
    }

    var errors: [String] = []
    var warnings: [String] = []
    let arguments = Array(tokens.dropFirst(2))
    let knownFlags = Dictionary(uniqueKeysWithValues: command.flags.map { ($0.name, $0) })
    let parsed = parse(arguments: arguments, knownFlags: knownFlags)
    errors.append(contentsOf: parsed.errors)

    let missingFlags = command.flags.filter { $0.required && !parsed.flags.contains($0.name) }
    errors.append(contentsOf: missingFlags.map { "Missing required flag \($0.name)." })

    let requiredPositionals = command.positionals.filter(\.required).count
    if parsed.positionals.count < requiredPositionals {
      errors.append("Missing required positional argument.")
    } else if command.positionals.isEmpty && !parsed.positionals.isEmpty {
      warnings.append("Command catalog does not define positional arguments for extra text.")
    } else if command.positionals.count > 1 && parsed.positionals.count > command.positionals.count {
      warnings.append("Command has more positional values than the catalog defines.")
    }
    return result(tokens, commandId, command, errors, warnings)
  }

  private static func parse(
    arguments: [String],
    knownFlags: [String: CommandFlagDTO]
  ) -> (flags: Set<String>, positionals: [String], errors: [String]) {
    var flags: Set<String> = []
    var seenFlags: Set<String> = []
    var positionals: [String] = []
    var errors: [String] = []
    var index = 0
    while index < arguments.count {
      let argument = arguments[index]
      guard argument.hasPrefix("--") else {
        positionals.append(argument)
        index += 1
        continue
      }
      guard let flag = knownFlags[argument] else {
        errors.append("Unknown flag \(argument).")
        index += 1
        continue
      }
      if seenFlags.contains(argument), !flag.repeatable {
        errors.append("Flag \(argument) is not repeatable.")
      }
      seenFlags.insert(argument)
      flags.insert(argument)
      if flag.value != nil {
        guard arguments.indices.contains(index + 1), !arguments[index + 1].hasPrefix("--") else {
          errors.append("Missing value for \(argument).")
          index += 1
          continue
        }
        index += 2
      } else {
        index += 1
      }
    }
    return (flags, positionals, errors)
  }

  private static func result(
    _ tokens: [String],
    _ commandId: String?,
    _ command: CommandReferenceDTO?,
    _ errors: [String],
    _ warnings: [String]
  ) -> AgentValidationDTO {
    AgentValidationDTO(
      schemaVersion: 1,
      valid: errors.isEmpty,
      commandId: commandId,
      normalizedCommand: tokens,
      errors: errors,
      warnings: warnings,
      command: command)
  }
}
