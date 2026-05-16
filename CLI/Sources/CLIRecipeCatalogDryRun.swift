import Foundation

extension CLIRecipeCatalog {
  static let dryRunRecipes: [RecipeReferenceDTO] = [
    recipe(
      "posting.create-with-media-dry-run",
      "Safely preview and then create a queued post with image or video media.",
      goal:
        "Inspect state, preview capture creation with --dry-run, wait for confirmation, execute the create, and verify the result.",
      inputs: [
        input("title", "Post title."),
        input("text", "Post body."),
        input("mediaPath", "Local image or video path to attach."),
        input("subreddit", "Existing subreddit name or id."),
        input("due", "ISO8601 posting-window date."),
        input("project", "Optional existing project name or id.", required: false),
      ],
      steps: [
        step(
          1, "context.show",
          "Inspect current projects, subreddits, queued captures, and upcoming events.",
          "redditreminder --json context show --limit 10"),
        step(
          2, "subreddits.search",
          "Confirm the target subreddit exists before previewing the mutation.",
          "redditreminder --json subreddits search --query SideProject"),
        step(
          3, "captures.create",
          "Preview the capture creation without saving app data.",
          "redditreminder --json --dry-run captures create --title 'Launch' --text 'Body' --subreddit SideProject --media ~/Desktop/mock.png --due 2026-05-02T18:00:00Z"
        ),
        step(
          4, "captures.create",
          "After user confirmation, create the capture and due posting-window event.",
          "redditreminder --json captures create --title 'Launch' --text 'Body' --subreddit SideProject --media ~/Desktop/mock.png --due 2026-05-02T18:00:00Z"
        ),
        step(
          5, "context.show",
          "Verify the queued capture and event are visible.",
          "redditreminder --json context show --limit 10"),
      ],
      examples: ["redditreminder --json recipes show posting.create-with-media-dry-run"],
      relatedCommands: ["context.show", "subreddits.search", "captures.create"]
    ),
    recipe(
      "subreddit.configure-peak-times-dry-run",
      "Add subreddit safely by verifying it, previewing changes, and configuring peak times.",
      goal:
        "Verify the subreddit, inspect current peak settings, preview the peak override, wait for confirmation, apply it, and verify generated events.",
      inputs: [
        input("subreddit", "Existing subreddit name or id."),
        input("days", "Comma-separated day keys such as mon,wed,fri."),
        input("hours", "Comma-separated local hours 0-23."),
        input("timezone", "Optional IANA timezone id.", required: false),
      ],
      steps: [
        step(
          1, "subreddits.verify",
          "Optionally verify the subreddit exists on Reddit before changing local config.",
          "redditreminder --json subreddits verify SideProject"),
        step(
          2, "peaks.get",
          "Inspect the current effective peak configuration.",
          "redditreminder --json peaks get SideProject"),
        step(
          3, "peaks.set",
          "Preview the peak override without saving app data.",
          "redditreminder --json --dry-run peaks set SideProject --days mon,wed --hours 9,10 --timezone America/Phoenix"
        ),
        step(
          4, "peaks.set",
          "After user confirmation, save the peak override and resync generated events.",
          "redditreminder --json peaks set SideProject --days mon,wed --hours 9,10 --timezone America/Phoenix"
        ),
        step(
          5, "peaks.get",
          "Verify the updated effective peak configuration.",
          "redditreminder --json peaks get SideProject"),
      ],
      examples: ["redditreminder --json recipes show subreddit.configure-peak-times-dry-run"],
      relatedCommands: ["subreddits.verify", "peaks.get", "peaks.set"]
    ),
    recipe(
      "project.archive-dry-run",
      "Safely preview and then archive a project.",
      goal:
        "Find the project, preview archival with --dry-run, wait for confirmation, archive it, and verify project state.",
      inputs: [
        input("project", "Existing project name or id.")
      ],
      steps: [
        step(
          1, "projects.search",
          "Find the target project and confirm the intended id or name.",
          "redditreminder --json projects search --query Launch"),
        step(
          2, "projects.update",
          "Preview archiving the project without saving app data.",
          "redditreminder --json --dry-run projects update Launch --archive"),
        step(
          3, "projects.update",
          "After user confirmation, archive the project.",
          "redditreminder --json projects update Launch --archive"),
        step(
          4, "projects.list",
          "Verify the project is archived.",
          "redditreminder --json projects list --query Launch"),
      ],
      examples: ["redditreminder --json recipes show project.archive-dry-run"],
      relatedCommands: ["projects.search", "projects.update", "projects.list"]
    ),
  ]
}
