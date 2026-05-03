import Foundation

enum CLIAgentBootstrap {
  static func show() -> CLIResponse {
    .success(
      data: .agentBootstrap(
        AgentBootstrapDTO(
          schemaVersion: 1,
          toolName: "redditreminder",
          summary:
            "Cold-start guide for agents using the RedditReminder menu bar app through the CLI.",
          recommendedStart: [
            "redditreminder --json agent bootstrap",
            "redditreminder --json context show --limit 10",
            "redditreminder --json commands list",
            "redditreminder --json recipes list",
            "redditreminder --json recipes search --query dry-run",
          ],
          safety: [
            "Prefer recipes before composing raw mutation commands.",
            "Use --dry-run before mutations when the command supports it.",
            "Ask for user confirmation before executing non-dry-run mutations.",
            "Use --store PATH for isolated testing without touching app data.",
          ],
          discoveryCommands: [
            "context.show",
            "search.all",
            "commands.list",
            "commands.show",
            "recipes.list",
            "recipes.search",
            "recipes.show",
          ],
          recipeCommands: [
            "redditreminder --json recipes list",
            "redditreminder --json recipes search --query media",
            "redditreminder --json recipes search --query dry-run",
            "redditreminder --json recipes show posting.create-with-media-dry-run",
          ],
          coreWorkflows: [
            "posting.create-with-media",
            "posting.create-with-media-dry-run",
            "workspace.recommend-targets",
            "subreddit.configure-peak-times",
            "subreddit.configure-peak-times-dry-run",
            "project.archive-dry-run",
          ],
          docs: [
            "docs/cli.md",
            "scripts/cli-smoke.sh",
            "scripts/cli-catalog-check.py",
          ])))
  }
}
