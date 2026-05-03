import Foundation

enum CLIAgentDryRunner {
  static let mutationCommands: Set<String> = [
    "captures.create",
    "captures.update",
    "captures.delete",
    "captures.mark-posted",
    "captures.mark-queued",
    "events.create",
    "events.update",
    "events.delete",
    "projects.create",
    "projects.update",
    "projects.delete",
    "subreddits.add",
    "subreddits.update",
    "subreddits.delete",
    "peaks.set",
    "peaks.reset",
  ]

  @MainActor
  static func dryRun(input: AgentValidateInput, options: CLIOptions) async throws -> CLIResponse {
    let tokens = CLIAgentValidator.normalizedCommand(input.command)
    let validation = CLIAgentValidator.validationResult(for: tokens)
    guard validation.valid else {
      return .success(data: .agentDryRun(failed(tokens, validation, validation.errors)))
    }
    guard let commandId = validation.commandId, mutationCommands.contains(commandId) else {
      let error = "Command is read-only or does not support dry-run."
      return .success(data: .agentDryRun(failed(tokens, validation, [error])))
    }

    var dryOptions = options
    dryOptions.dryRun = true
    let invocation = try CLIInvocation(arguments: tokens)
    let runner = try CLIRunner(options: dryOptions)
    let preview = try await runner.run(command: invocation.command)
    return .success(
      data: .agentDryRun(
        AgentDryRunDTO(
          schemaVersion: 1,
          valid: true,
          wouldRun: tokens,
          requiresConfirmation: true,
          validation: validation,
          preview: previewDTO(from: preview),
          errors: [])))
  }

  private static func failed(
    _ tokens: [String],
    _ validation: AgentValidationDTO,
    _ errors: [String]
  ) -> AgentDryRunDTO {
    AgentDryRunDTO(
      schemaVersion: 1,
      valid: false,
      wouldRun: tokens,
      requiresConfirmation: false,
      validation: validation,
      preview: nil,
      errors: errors)
  }

  private static func previewDTO(from response: CLIResponse) -> AgentDryRunPreviewDTO {
    let message: String?
    if case .dryRun(let value)? = response.data {
      message = value
    } else {
      message = nil
    }
    return AgentDryRunPreviewDTO(
      ok: response.ok,
      message: message,
      warnings: response.warnings,
      errors: response.errors)
  }
}
