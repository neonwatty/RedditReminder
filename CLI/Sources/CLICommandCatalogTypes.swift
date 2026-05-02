import Foundation

struct CommandReferenceDTO: Encodable {
  let id: String
  let domain: String
  let command: String
  let summary: String
  let positionals: [CommandArgumentDTO]
  let flags: [CommandFlagDTO]
  let examples: [String]
  let output: CommandOutputDTO
}

struct CommandArgumentDTO: Encodable {
  let name: String
  let required: Bool
  let summary: String
}

struct CommandFlagDTO: Encodable {
  let name: String
  let value: String?
  let required: Bool
  let repeatable: Bool
  let summary: String
}

struct CommandOutputDTO: Encodable {
  let data: String
  let summary: String
}
