import Foundation

extension CLICommandCatalog {
  static let eventCommands: [CommandReferenceDTO] = [
    command(
      "events.list", "events", "list",
      "List posting events.",
      flags: eventListFlags(),
      examples: ["redditreminder --json events list --subreddit SideProject --active"],
      output: output("events", "Array of event objects.")
    ),
    command(
      "events.search", "events", "search",
      "Search posting events.",
      flags: [flag("--query", "TEXT", "Search text.", required: true)] + eventListFlags(),
      examples: ["redditreminder --json events search --query launch --manual"],
      output: output("events", "Array of event objects.")
    ),
    command(
      "events.create", "events", "create",
      "Create a manual one-off posting event.",
      flags: [
        flag("--subreddit", "NAME_OR_ID", "Existing subreddit.", required: true),
        flag("--name", "TEXT", "Event name."),
        flag("--date", "ISO8601", "Event date.", required: true),
        flag("--lead-minutes", "N", "Reminder lead time."),
      ],
      examples: [
        "redditreminder --json events create --subreddit SideProject --date 2026-05-02T18:00:00Z"
      ],
      output: output("event", "Created event object.")
    ),
    command(
      "events.update", "events", "update",
      "Update a manual event.",
      positionals: [arg("id", "Event UUID or unambiguous prefix.")],
      flags: [
        flag("--name", "TEXT", "Set event name."),
        flag("--date", "ISO8601", "Set one-off date."),
        flag("--lead-minutes", "N", "Set reminder lead time."),
        flag("--activate", nil, "Activate event."),
        flag("--deactivate", nil, "Deactivate event."),
      ],
      examples: ["redditreminder --json events update EVENT_ID --deactivate"],
      output: output("event", "Updated event object.")
    ),
    command(
      "events.delete", "events", "delete",
      "Delete a manual event.",
      positionals: [arg("id", "Event UUID or unambiguous prefix.")],
      examples: ["redditreminder --json events delete EVENT_ID"],
      output: output("deleted", "Deleted id.")
    ),
  ]
}
