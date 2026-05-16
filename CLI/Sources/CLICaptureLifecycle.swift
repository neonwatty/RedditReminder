import Foundation
import SwiftData

@MainActor
struct CLICaptureLifecycle {
  let options: CLIOptions
  let context: ModelContext

  func update(input: CaptureUpdateInput) throws -> CLIResponse {
    let capture = try findCapture(input.id)
    let mediaStore = MediaStore(rootDir: CLIStore.mediaRootURL(from: options.storePath))

    let title = input.clearTitle ? nil : input.title ?? capture.title
    let text = input.text ?? capture.text
    guard title?.isEmpty == false || !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
      throw CLIError.validation("Capture must keep a title or text body.")
    }

    let project: Project?
    if input.clearProject {
      project = nil
    } else {
      project = try input.project.map(findProject) ?? capture.project
    }

    let subreddits: [Subreddit]
    if input.clearSubreddits {
      subreddits = []
    } else if let inputSubreddits = input.subreddits {
      subreddits = try inputSubreddits.map(findSubreddit)
    } else {
      subreddits = capture.subreddits
    }

    let removedMediaRefs = input.clearMedia ? capture.mediaRefs : input.removedMediaRefs
    if options.dryRun {
      return .success(data: .dryRun("Would update capture \(capture.id.uuidString)."))
    }

    let result = CaptureFormResult(
      title: title,
      text: text,
      notes: input.clearNotes ? nil : input.notes ?? capture.notes,
      links: input.clearLinks ? [] : input.links ?? capture.links,
      project: project,
      subreddits: subreddits,
      mediaURLs: try input.mediaPaths.map(mediaURL),
      removedMediaRefs: removedMediaRefs
    )
    guard
      CapturePersistenceActions.updateCapture(
        capture, with: result, modelContext: context, mediaStore: mediaStore)
    else {
      throw CLIError.runtime("Could not update capture \(capture.id.uuidString).")
    }
    return .success(data: .capture(CaptureDTO(capture)))
  }

  func delete(id: String) throws -> CLIResponse {
    let capture = try findCapture(id)
    if options.dryRun {
      return .success(data: .dryRun("Would delete capture \(capture.id.uuidString)."))
    }
    let deletedId = capture.id.uuidString
    let mediaStore = MediaStore(rootDir: CLIStore.mediaRootURL(from: options.storePath))
    try CapturePersistenceActions.deleteCapture(
      capture, modelContext: context, mediaStore: mediaStore)
    return .success(data: .deleted(DeletedDTO(id: deletedId)))
  }

  func markPosted(input: CapturePostStatusInput) throws -> CLIResponse {
    let capture = try findCapture(input.id)
    let subreddit = try input.subreddit.map(findSubreddit)
    if let subreddit, !capture.subreddits.contains(where: { $0.id == subreddit.id }) {
      throw CLIError.validation("\(subreddit.name) is not a target subreddit for this capture.")
    }
    if options.dryRun {
      let target = subreddit.map { " for \($0.name)" } ?? ""
      return .success(data: .dryRun("Would mark capture \(capture.id.uuidString) posted\(target)."))
    }
    if let subreddit {
      capture.markSubredditAsPosted(subreddit.id)
      if capture.status == .posted {
        capture.postedURL = input.url
      }
    } else {
      capture.markAsPosted(postedURL: input.url)
    }
    try context.save()
    return .success(data: .capture(CaptureDTO(capture)))
  }

  func markQueued(input: CaptureQueueStatusInput) throws -> CLIResponse {
    let capture = try findCapture(input.id)
    let subreddit = try input.subreddit.map(findSubreddit)
    if let subreddit, !capture.subreddits.contains(where: { $0.id == subreddit.id }) {
      throw CLIError.validation("\(subreddit.name) is not a target subreddit for this capture.")
    }
    if options.dryRun {
      let target = subreddit.map { " for \($0.name)" } ?? ""
      return .success(data: .dryRun("Would mark capture \(capture.id.uuidString) queued\(target)."))
    }
    if let subreddit {
      capture.markSubredditAsUnposted(subreddit.id)
      if capture.status == .queued {
        capture.postedURL = nil
      }
    } else {
      capture.markAsQueued()
    }
    try context.save()
    return .success(data: .capture(CaptureDTO(capture)))
  }

  private func findCapture(_ input: String) throws -> Capture {
    let captures = (try? context.fetch(FetchDescriptor<Capture>())) ?? []
    let matches = captures.filter { capture in
      capture.id.uuidString == input
        || capture.id.uuidString.lowercased().hasPrefix(input.lowercased())
    }
    if matches.count == 1, let capture = matches.first { return capture }
    if matches.count > 1 { throw CLIError.validation("Capture id prefix is ambiguous: \(input)") }
    throw CLIError.notFound("Capture not found: \(input)")
  }

  private func findProject(_ input: String) throws -> Project {
    let projects =
      (try? context.fetch(FetchDescriptor<Project>(sortBy: [SortDescriptor(\.name)]))) ?? []
    if let project = projects.first(where: {
      $0.id.uuidString == input || $0.name.caseInsensitiveCompare(input) == .orderedSame
    }) {
      return project
    }
    throw CLIError.notFound("Project not found: \(input)")
  }

  private func findSubreddit(_ input: String) throws -> Subreddit {
    let normalized = SubredditName.normalizedName(input) ?? input
    let subreddits =
      (try? context.fetch(FetchDescriptor<Subreddit>(sortBy: [SortDescriptor(\.sortOrder)]))) ?? []
    if let subreddit = subreddits.first(where: {
      $0.id.uuidString == input || $0.name.caseInsensitiveCompare(normalized) == .orderedSame
    }) {
      return subreddit
    }
    throw CLIError.notFound("Subreddit not found: \(input)")
  }

  private func mediaURL(_ path: String) throws -> URL {
    let url = URL(fileURLWithPath: NSString(string: path).expandingTildeInPath)
    guard FileManager.default.fileExists(atPath: url.path) else {
      throw CLIError.notFound("Media file not found: \(path)")
    }
    return url
  }
}
