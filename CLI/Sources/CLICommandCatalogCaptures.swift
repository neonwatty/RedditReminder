import Foundation

extension CLICommandCatalog {
  static let captureCommands: [CommandReferenceDTO] = [
    command(
      "captures.list", "captures", "list",
      "List queued and posted captures.",
      flags: [flag("--query", "TEXT", "Optional search text.")],
      examples: ["redditreminder --json captures list"],
      output: output("captures", "Array of capture objects.")
    ),
    command(
      "captures.search", "captures", "search",
      "Search captures.",
      flags: [flag("--query", "TEXT", "Search text.", required: true)],
      examples: ["redditreminder --json captures search --query launch"],
      output: output("captures", "Array of capture objects.")
    ),
    command(
      "captures.create", "captures", "create",
      "Create a queued capture for one or more existing subreddits, optionally with media and due events.",
      flags: [
        flag("--title", "TEXT", "Optional post title."),
        flag("--text", "TEXT", "Post body. Trailing text is used when omitted."),
        flag("--notes", "TEXT", "Private notes."),
        flag("--link", "URL", "Add one link.", repeatable: true),
        flag("--links", "A,B", "Comma-separated links."),
        flag("--project", "NAME_OR_ID", "Existing project."),
        flag(
          "--subreddit", "NAME_OR_ID", "Existing subreddit. Required unless --subreddits is used.",
          repeatable: true),
        flag(
          "--subreddits", "A,B", "Comma-separated subreddits. Required unless --subreddit is used."),
        flag("--media", "PATH", "Image or video path to copy into media store.", repeatable: true),
        flag("--media-paths", "A,B", "Comma-separated image or video paths."),
        flag("--due", "ISO8601", "Create one due event per selected subreddit."),
      ],
      examples: [
        "redditreminder --json captures create --title 'Launch' --text 'Body' --subreddit SideProject"
      ],
      output: output("captureCreated", "Created capture plus due events.")
    ),
    command(
      "captures.update", "captures", "update",
      "Update a capture.",
      positionals: [arg("id", "Capture UUID.")],
      flags: [
        flag("--title", "TEXT", "Set title."),
        flag("--clear-title", nil, "Clear title."),
        flag("--text", "TEXT", "Set body."),
        flag("--notes", "TEXT", "Set notes."),
        flag("--clear-notes", nil, "Clear notes."),
        flag("--link", "URL", "Replace links with repeated values.", repeatable: true),
        flag("--links", "A,B", "Replace links with comma-separated values."),
        flag("--clear-links", nil, "Clear links."),
        flag("--project", "NAME_OR_ID", "Set project."),
        flag("--clear-project", nil, "Clear project."),
        flag("--subreddit", "NAME_OR_ID", "Replace subreddits.", repeatable: true),
        flag("--subreddits", "A,B", "Replace subreddits."),
        flag("--clear-subreddits", nil, "Clear subreddits."),
        flag("--media", "PATH", "Add media.", repeatable: true),
        flag("--remove-media", "REF", "Remove stored media ref.", repeatable: true),
        flag("--clear-media", nil, "Clear all media."),
      ],
      examples: ["redditreminder --json captures update CAPTURE_ID --title 'Updated'"],
      output: output("capture", "Updated capture object.")
    ),
    command(
      "captures.delete", "captures", "delete",
      "Delete a capture.",
      positionals: [arg("id", "Capture UUID.")],
      examples: ["redditreminder --json captures delete CAPTURE_ID"],
      output: output("deleted", "Deleted id.")
    ),
    command(
      "captures.mark-posted", "captures", "mark-posted",
      "Mark a capture, or one target subreddit on a capture, as posted.",
      positionals: [arg("id", "Capture UUID.")],
      flags: [
        flag("--subreddit", "NAME_OR_ID", "Mark only this target subreddit as posted."),
        flag("--url", "URL", "Posted Reddit URL."),
      ],
      examples: [
        "redditreminder --json captures mark-posted CAPTURE_ID --subreddit SideProject",
        "redditreminder --json captures mark-posted CAPTURE_ID --url https://reddit.com/...",
      ],
      output: output("capture", "Updated capture object.")
    ),
    command(
      "captures.mark-queued", "captures", "mark-queued",
      "Move a posted capture, or one target subreddit on a capture, back to queued.",
      positionals: [arg("id", "Capture UUID.")],
      flags: [flag("--subreddit", "NAME_OR_ID", "Move only this target subreddit back to queued.")],
      examples: [
        "redditreminder --json captures mark-queued CAPTURE_ID --subreddit SideProject",
        "redditreminder --json captures mark-queued CAPTURE_ID",
      ],
      output: output("capture", "Updated capture object.")
    ),
  ]
}
