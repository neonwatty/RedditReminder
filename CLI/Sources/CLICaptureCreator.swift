import Foundation
import SwiftData

@MainActor
struct CLICaptureCreator {
  let options: CLIOptions
  let context: ModelContext

  func create(input: CaptureCreateInput) throws -> CLIResponse {
    let project = try input.project.map(findProject)
    let subreddits = try input.subreddits.map(findSubreddit)
    let mediaURLs = try input.mediaPaths.map(mediaURL)
    let dueDate = try input.due.map(parseDate)

    if options.dryRun {
      return .success(
        data: .dryRun(
          "Would create capture with \(subreddits.count) subreddit(s), \(mediaURLs.count) media file(s), and \(dueDate == nil ? 0 : subreddits.count) due event(s)."
        ))
    }

    let capture = Capture(
      title: input.title,
      text: input.text,
      notes: input.notes,
      links: input.links,
      mediaRefs: [],
      project: project,
      subreddits: subreddits
    )
    context.insert(capture)

    let mediaStore = MediaStore(rootDir: CLIStore.mediaRootURL(from: options.storePath))
    do {
      capture.mediaRefs = try CapturePersistenceActions.saveMediaFiles(
        mediaURLs,
        captureId: capture.id,
        mediaStore: mediaStore
      )
      let events =
        dueDate.map { createDueEvents(date: $0, capture: capture, subreddits: subreddits) }
        ?? []
      try context.save()
      return .success(
        data: .captureCreated(
          CaptureCreateDTO(capture: CaptureDTO(capture), events: events.map(SubredditEventDTO.init))
        ))
    } catch {
      mediaStore.deleteAll(captureId: capture.id)
      context.delete(capture)
      throw CLIError.runtime("Could not create capture: \(error.localizedDescription)")
    }
  }

  private func findProject(_ input: String) throws -> Project {
    let descriptor = FetchDescriptor<Project>(sortBy: [SortDescriptor(\.name)])
    let projects = (try? context.fetch(descriptor)) ?? []
    if let project = projects.first(where: {
      $0.id.uuidString == input || $0.name.caseInsensitiveCompare(input) == .orderedSame
    }) {
      return project
    }
    throw CLIError.notFound("Project not found: \(input)")
  }

  private func findSubreddit(_ input: String) throws -> Subreddit {
    let normalized = SubredditName.normalizedName(input) ?? input
    let descriptor = FetchDescriptor<Subreddit>(sortBy: [SortDescriptor(\.sortOrder)])
    let subreddits = (try? context.fetch(descriptor)) ?? []
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

  private func parseDate(_ value: String) throws -> Date {
    if let date = ISO8601DateFormatter().date(from: value) { return date }
    throw CLIError.validation("Due date must be ISO-8601, for example 2026-05-02T15:00:00Z.")
  }

  private func createDueEvents(
    date: Date,
    capture: Capture,
    subreddits: [Subreddit]
  ) -> [SubredditEvent] {
    subreddits.map { subreddit in
      let event = SubredditEvent(
        name: dueEventName(for: capture),
        subreddit: subreddit,
        oneOffDate: date,
        reminderLeadMinutes: defaultLeadTimeMinutes,
        isGeneratedFromHeuristics: false
      )
      context.insert(event)
      return event
    }
  }

  private func dueEventName(for capture: Capture) -> String {
    let raw =
      capture.title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
      ? capture.title ?? ""
      : capture.text
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    return "Post: \(String(trimmed.prefix(48)))"
  }

  private var defaultLeadTimeMinutes: Int {
    UserDefaults.standard.object(forKey: SettingsKey.defaultLeadTimeMinutes) as? Int ?? 60
  }
}
