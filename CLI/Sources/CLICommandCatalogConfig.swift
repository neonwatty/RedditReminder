import Foundation

extension CLICommandCatalog {
  static let projectCommands: [CommandReferenceDTO] = [
    command(
      "projects.list", "projects", "list",
      "List projects.",
      flags: [flag("--query", "TEXT", "Optional search text.")],
      examples: ["redditreminder --json projects list"],
      output: output("projects", "Array of project objects.")
    ),
    command(
      "projects.search", "projects", "search",
      "Search projects.",
      flags: [flag("--query", "TEXT", "Search text.", required: true)],
      examples: ["redditreminder --json projects search --query launch"],
      output: output("projects", "Array of project objects.")
    ),
    command(
      "projects.create", "projects", "create",
      "Create a project.",
      positionals: [arg("name", "Project name.")],
      examples: ["redditreminder --json projects create 'Launch Ideas'"],
      output: output("project", "Created project object.")
    ),
    command(
      "projects.update", "projects", "update",
      "Update project metadata.",
      positionals: [arg("id", "Project UUID or name.")],
      flags: [
        flag("--name", "TEXT", "Rename project."),
        flag("--description", "TEXT", "Set description."),
        flag("--clear-description", nil, "Clear description."),
        flag("--color", "TEXT", "Set color."),
        flag("--clear-color", nil, "Clear color."),
        flag("--archive", nil, "Archive project."),
        flag("--unarchive", nil, "Unarchive project."),
      ],
      examples: ["redditreminder --json projects update Launch --archive"],
      output: output("project", "Updated project object.")
    ),
    command(
      "projects.delete", "projects", "delete",
      "Delete a project. Captures assigned to it are cascaded by the app model.",
      positionals: [arg("id", "Project UUID or name.")],
      examples: ["redditreminder --json projects delete Launch"],
      output: output("deleted", "Deleted id.")
    ),
  ]

  static let subredditCommands: [CommandReferenceDTO] = [
    command(
      "subreddits.list", "subreddits", "list",
      "List subreddits with peak summaries.",
      flags: [flag("--query", "TEXT", "Optional search text.")],
      examples: ["redditreminder --json subreddits list"],
      output: output("subreddits", "Array of subreddit objects.")
    ),
    command(
      "subreddits.search", "subreddits", "search",
      "Search subreddits.",
      flags: [flag("--query", "TEXT", "Search text.", required: true)],
      examples: ["redditreminder --json subreddits search --query swift"],
      output: output("subreddits", "Array of subreddit objects.")
    ),
    command(
      "subreddits.add", "subreddits", "add",
      "Add a subreddit and generate bundled peak events.",
      positionals: [arg("name", "Subreddit name or Reddit URL.")],
      flags: [flag("--verify", nil, "Verify against Reddit before saving.")],
      examples: ["redditreminder --json subreddits add --verify SideProject"],
      output: output("subreddit", "Created subreddit object.")
    ),
    command(
      "subreddits.update", "subreddits", "update",
      "Update a subreddit name or posting checklist.",
      positionals: [arg("id", "Subreddit UUID or name.")],
      flags: [
        flag("--name", "TEXT", "Rename subreddit."),
        flag("--checklist", "TEXT", "Set posting checklist."),
        flag("--clear-checklist", nil, "Clear posting checklist."),
      ],
      examples: ["redditreminder --json subreddits update SideProject --checklist 'Read rules'"],
      output: output("subreddit", "Updated subreddit object.")
    ),
    command(
      "subreddits.delete", "subreddits", "delete",
      "Delete a subreddit, cascading events while preserving captures.",
      positionals: [arg("id", "Subreddit UUID or name.")],
      examples: ["redditreminder --json subreddits delete SideProject"],
      output: output("deleted", "Deleted id.")
    ),
    command(
      "subreddits.verify", "subreddits", "verify",
      "Check whether Reddit exposes the subreddit about endpoint.",
      positionals: [arg("name", "Subreddit name or Reddit URL.")],
      examples: ["redditreminder --json subreddits verify SideProject"],
      output: output("subredditVerification", "Verification result.")
    ),
  ]

  static let peakCommands: [CommandReferenceDTO] = [
    command(
      "peaks.presets", "peaks", "presets",
      "List bundled peak-time presets.",
      examples: ["redditreminder --json peaks presets"],
      output: output("peakPresets", "Array of preset objects.")
    ),
    command(
      "peaks.get", "peaks", "get",
      "Show peak-time configuration for a subreddit.",
      positionals: [arg("subreddit", "Subreddit UUID or name.")],
      examples: ["redditreminder --json peaks get SideProject"],
      output: output("peakInfo", "Peak summary object.")
    ),
    command(
      "peaks.set", "peaks", "set",
      "Set peak days and local hours for a subreddit.",
      positionals: [arg("subreddit", "Subreddit UUID or name.")],
      flags: [
        flag("--days", "mon,tue", "Comma-separated day keys.", required: true),
        flag("--hours", "9,10", "Comma-separated local hours 0-23.", required: true),
        flag("--timezone", "ID", "IANA timezone. Defaults to current timezone."),
      ],
      examples: ["redditreminder --json peaks set SideProject --days mon,wed --hours 9,10"],
      output: output("peakInfo", "Updated peak summary object.")
    ),
    command(
      "peaks.reset", "peaks", "reset",
      "Clear custom peak overrides for a subreddit.",
      positionals: [arg("subreddit", "Subreddit UUID or name.")],
      examples: ["redditreminder --json peaks reset SideProject"],
      output: output("peakInfo", "Updated peak summary object.")
    ),
  ]
}
