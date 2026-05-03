import Foundation

struct CommandReferenceDTO: Encodable {
  let schemaVersion: Int
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

struct RecipeReferenceDTO: Encodable {
  let schemaVersion: Int
  let id: String
  let summary: String
  let goal: String
  let inputs: [RecipeInputDTO]
  let steps: [RecipeStepDTO]
  let examples: [String]
  let relatedCommands: [String]
}

struct RecipeInputDTO: Encodable {
  let name: String
  let required: Bool
  let summary: String
}

struct RecipeStepDTO: Encodable {
  let order: Int
  let commandId: String
  let purpose: String
  let example: String
}

struct AgentBootstrapDTO: Encodable {
  let schemaVersion: Int
  let toolName: String
  let summary: String
  let installCommands: [String]
  let binaryLocations: [String]
  let recommendedStart: [String]
  let safety: [String]
  let discoveryCommands: [String]
  let recipeCommands: [String]
  let coreWorkflows: [String]
  let commandSchemas: [CommandReferenceDTO]
  let recipeSchemas: [RecipeReferenceDTO]
  let docs: [String]
}

struct AgentValidationDTO: Encodable {
  let schemaVersion: Int
  let valid: Bool
  let commandId: String?
  let normalizedCommand: [String]
  let errors: [String]
  let warnings: [String]
  let command: CommandReferenceDTO?
}
