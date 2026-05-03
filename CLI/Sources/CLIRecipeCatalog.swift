import Foundation

enum CLIRecipeCatalog {
  static func list() -> CLIResponse {
    .success(data: .recipeReferences(recipes))
  }

  static func search(query: String) -> CLIResponse {
    .success(
      data: .recipeReferences(
        CLIFilter.items(recipes, query: query, searchableText: searchableText)))
  }

  static func show(id input: String) throws -> CLIResponse {
    let normalized = input.lowercased()
    guard let recipe = recipes.first(where: { $0.id == normalized }) else {
      throw CLIError.notFound("Recipe not found: \(input)")
    }
    return .success(data: .recipeReference(recipe))
  }

  private static func searchableText(for recipe: RecipeReferenceDTO) -> String {
    (
      [
        recipe.id,
        recipe.summary,
        recipe.goal,
        recipe.examples.joined(separator: " "),
        recipe.relatedCommands.joined(separator: " "),
      ]
      + recipe.inputs.map { "\($0.name) \($0.summary)" }
      + recipe.steps.map { "\($0.commandId) \($0.purpose) \($0.example)" }
    ).joined(separator: " ")
  }

  static let recipes: [RecipeReferenceDTO] = [
    recipe(
      "posting.create-with-media",
      "Create a queued post with image media and a due posting window.",
      goal: "Given a title, body, image path, subreddit, and due date, create the capture and its posting-window event.",
      inputs: [
        input("title", "Post title."),
        input("text", "Post body."),
        input("mediaPath", "Local image path to attach."),
        input("subreddit", "Existing subreddit name or id."),
        input("due", "ISO8601 posting-window date."),
        input("project", "Optional existing project name or id.", required: false),
      ],
      steps: [
        step(
          1, "subreddits.search",
          "Confirm the subreddit already exists in the workspace.",
          "redditreminder --json subreddits search --query SideProject"),
        step(
          2, "captures.create",
          "Create the queued capture, copy media, and add a due event.",
          "redditreminder --json captures create --title 'Launch' --text 'Body' --subreddit SideProject --media ~/Desktop/mock.png --due 2026-05-02T18:00:00Z"),
        step(
          3, "context.show",
          "Verify the queued capture and upcoming event are visible.",
          "redditreminder --json context show --limit 5"),
      ],
      examples: ["redditreminder --json recipes show posting.create-with-media"],
      relatedCommands: ["subreddits.search", "captures.create", "context.show"]
    ),
    recipe(
      "workspace.recommend-targets",
      "Inspect the workspace before recommending subreddits and times.",
      goal: "Gather enough state to recommend where and when a draft should be posted without mutating data.",
      inputs: [
        input("topic", "Topic or launch text to search for."),
        input("limit", "Maximum rows per context collection.", required: false),
      ],
      steps: [
        step(
          1, "context.show",
          "Read projects, subreddits, peak summaries, queued captures, events, and presets.",
          "redditreminder --json context show --limit 10"),
        step(
          2, "search.all",
          "Find matching captures, events, projects, subreddits, and presets.",
          "redditreminder --json search all --query launch --limit 10"),
        step(
          3, "peaks.presets",
          "Inspect bundled peak-time patterns when a subreddit has no override.",
          "redditreminder --json peaks presets"),
      ],
      examples: ["redditreminder --json recipes show workspace.recommend-targets"],
      relatedCommands: ["context.show", "search.all", "peaks.presets"]
    ),
    recipe(
      "subreddit.configure-peak-times",
      "Add or verify a subreddit and configure its peak posting windows.",
      goal: "Create a subreddit safely, then apply local peak days and hours used to generate posting events.",
      inputs: [
        input("subreddit", "Subreddit name or Reddit URL."),
        input("days", "Comma-separated day keys such as mon,wed,fri."),
        input("hours", "Comma-separated local hours 0-23."),
        input("timezone", "Optional IANA timezone id.", required: false),
      ],
      steps: [
        step(
          1, "subreddits.verify",
          "Check Reddit before saving if the user wants real-subreddit validation.",
          "redditreminder --json subreddits verify SideProject"),
        step(
          2, "subreddits.add",
          "Add the subreddit, using --verify when validation is required.",
          "redditreminder --json subreddits add --verify SideProject"),
        step(
          3, "peaks.set",
          "Apply local peak days and hours; generated events resync automatically.",
          "redditreminder --json peaks set SideProject --days mon,wed --hours 9,10 --timezone America/Phoenix"),
        step(
          4, "peaks.get",
          "Confirm the effective peak configuration.",
          "redditreminder --json peaks get SideProject"),
      ],
      examples: ["redditreminder --json recipes show subreddit.configure-peak-times"],
      relatedCommands: ["subreddits.verify", "subreddits.add", "peaks.set", "peaks.get"]
    ),
  ]

  static func recipe(
    _ id: String,
    _ summary: String,
    goal: String,
    inputs: [RecipeInputDTO],
    steps: [RecipeStepDTO],
    examples: [String],
    relatedCommands: [String]
  ) -> RecipeReferenceDTO {
    RecipeReferenceDTO(
      schemaVersion: 1,
      id: id,
      summary: summary,
      goal: goal,
      inputs: inputs,
      steps: steps,
      examples: examples,
      relatedCommands: relatedCommands)
  }

  static func input(_ name: String, _ summary: String, required: Bool = true) -> RecipeInputDTO {
    RecipeInputDTO(name: name, required: required, summary: summary)
  }

  static func step(
    _ order: Int,
    _ commandId: String,
    _ purpose: String,
    _ example: String
  ) -> RecipeStepDTO {
    RecipeStepDTO(order: order, commandId: commandId, purpose: purpose, example: example)
  }
}
