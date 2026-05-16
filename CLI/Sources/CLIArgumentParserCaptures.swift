import Foundation

extension CLIArgumentParser {
  mutating func consumeCaptureCreateInput() throws -> CaptureCreateInput {
    let title = consumeOptionalValue(for: "--title")
    let textFlag = consumeOptionalValue(for: "--text")
    let notes = consumeOptionalValue(for: "--notes")
    let project = consumeOptionalValue(for: "--project")
    let due = consumeOptionalValue(for: "--due")
    let links =
      consumeRepeatedValues(for: "--link") + splitCSV(consumeOptionalValue(for: "--links"))
    let subreddits =
      consumeRepeatedValues(for: "--subreddit")
      + splitCSV(consumeOptionalValue(for: "--subreddits"))
    let mediaPaths =
      consumeRepeatedValues(for: "--media") + splitCSV(consumeOptionalValue(for: "--media-paths"))
    if let unexpected = firstRemainingFlag() {
      throw CLIError.usage("Unexpected capture create option: \(unexpected)")
    }
    let trailingText = consumeRemainingText()

    let input = CaptureCreateInput(
      title: normalizedOptional(title),
      text: (textFlag ?? trailingText).trimmingCharacters(in: .whitespacesAndNewlines),
      notes: normalizedOptional(notes),
      links: links,
      project: normalizedOptional(project),
      subreddits: subreddits,
      mediaPaths: mediaPaths,
      due: normalizedOptional(due)
    )
    guard input.title != nil || !input.text.isEmpty else {
      throw CLIError.usage("Capture create requires --text, --title, or trailing text.")
    }
    guard !input.subreddits.isEmpty else {
      throw CLIError.usage("Capture create requires --subreddit or --subreddits.")
    }
    return input
  }

  mutating func consumeCaptureUpdateInput() throws -> CaptureUpdateInput {
    let id = try consumeRequiredArgument(label: "capture id")
    let title = consumeOptionalValue(for: "--title")
    let text = consumeOptionalValue(for: "--text")
    let notes = consumeOptionalValue(for: "--notes")
    let project = consumeOptionalValue(for: "--project")
    let links =
      consumeRepeatedValues(for: "--link") + splitCSV(consumeOptionalValue(for: "--links"))
    let subreddits =
      consumeRepeatedValues(for: "--subreddit")
      + splitCSV(consumeOptionalValue(for: "--subreddits"))
    let mediaPaths =
      consumeRepeatedValues(for: "--media")
      + splitCSV(consumeOptionalValue(for: "--media-paths"))
    let removedMediaRefs =
      consumeRepeatedValues(for: "--remove-media")
      + splitCSV(consumeOptionalValue(for: "--remove-media-refs"))

    let input = CaptureUpdateInput(
      id: id,
      title: normalizedOptional(title),
      clearTitle: consumeFlag("--clear-title"),
      text: normalizedOptional(text),
      notes: normalizedOptional(notes),
      clearNotes: consumeFlag("--clear-notes"),
      links: links.isEmpty ? nil : links,
      clearLinks: consumeFlag("--clear-links"),
      project: normalizedOptional(project),
      clearProject: consumeFlag("--clear-project"),
      subreddits: subreddits.isEmpty ? nil : subreddits,
      clearSubreddits: consumeFlag("--clear-subreddits"),
      mediaPaths: mediaPaths,
      removedMediaRefs: removedMediaRefs,
      clearMedia: consumeFlag("--clear-media")
    )
    guard input.hasChanges else {
      throw CLIError.usage("Capture update requires at least one field flag.")
    }
    return input
  }

  mutating func consumeCapturePostStatusInput() throws -> CapturePostStatusInput {
    let id = try consumeRequiredArgument(label: "capture id")
    return CapturePostStatusInput(
      id: id,
      subreddit: normalizedOptional(consumeOptionalValue(for: "--subreddit")),
      url: normalizedOptional(consumeOptionalValue(for: "--url"))
    )
  }

  mutating func consumeCaptureQueueStatusInput() throws -> CaptureQueueStatusInput {
    CaptureQueueStatusInput(
      id: try consumeRequiredArgument(label: "capture id"),
      subreddit: normalizedOptional(consumeOptionalValue(for: "--subreddit"))
    )
  }
}
