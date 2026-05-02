import Foundation
import SwiftData

@MainActor
struct CLIDiscoveryManager {
  let context: ModelContext
  let heuristicsStore: HeuristicsStore

  func search(input: SearchInput) -> CLIResponse {
    let query = input.query.lowercased()
    let results =
      projectResults(query: query)
      + subredditResults(query: query)
      + captureResults(query: query)
      + eventResults(query: query)
      + peakPresetResults(query: query)
    return .success(data: .searchResults(Array(results.prefix(input.limit))))
  }

  func showContext(input: ContextInput) -> CLIResponse {
    let captures = fetchCaptures()
    let projects = fetchProjects()
    let subreddits = fetchSubreddits()
    let events = fetchEvents()
    let activeEvents = events.filter(\.isActive)
    let queuedCaptures = captures.filter { $0.status == .queued }
    let counts = ContextCountsDTO(
      capturesQueued: queuedCaptures.count,
      capturesPosted: captures.filter { $0.status == .posted }.count,
      projectsActive: projects.filter { !$0.archived }.count,
      projectsArchived: projects.filter(\.archived).count,
      subreddits: subreddits.count,
      eventsActive: activeEvents.count
    )
    let dto = ContextDTO(
      generatedAt: CLIFormat.date(Date()),
      counts: counts,
      projects: Array(projects.prefix(input.limit)).map(ProjectDTO.init),
      subreddits: Array(subreddits.prefix(input.limit)).map {
        SubredditDTO($0, peakInfo: heuristicsStore.peakInfo(for: $0))
      },
      queuedCaptures: Array(queuedCaptures.prefix(input.limit)).map(CaptureDTO.init),
      upcomingEvents: Array(activeEvents.prefix(input.limit)).map(EventDTO.init),
      peakPresets: SubredditPeakSelection.presets.map(PeakPresetDTO.init)
    )
    return .success(data: .context(dto))
  }

  private func projectResults(query: String) -> [SearchResultDTO] {
    fetchProjects().compactMap { project in
      let text = [project.id.uuidString, project.name, project.projectDescription ?? "", project.color ?? ""]
        .joined(separator: " ")
      guard text.lowercased().contains(query) else { return nil }
      return SearchResultDTO(
        kind: "project",
        id: project.id.uuidString,
        title: project.name,
        subtitle: project.archived ? "archived project" : "active project")
    }
  }

  private func subredditResults(query: String) -> [SearchResultDTO] {
    fetchSubreddits().compactMap { subreddit in
      let peak = heuristicsStore.peakInfo(for: subreddit)
      let text = [
        subreddit.id.uuidString,
        subreddit.name,
        subreddit.postingChecklist ?? "",
        peak?.peakDays.joined(separator: " ") ?? "",
        peak?.peakHoursUtc.map(String.init).joined(separator: " ") ?? "",
      ].joined(separator: " ")
      guard text.lowercased().contains(query) else { return nil }
      let summary = PeakSummaryDTO(subreddit: subreddit, peakInfo: peak)
      return SearchResultDTO(
        kind: "subreddit",
        id: subreddit.id.uuidString,
        title: subreddit.name,
        subtitle: "peak \(summary.source): \(summary.days.joined(separator: ","))")
    }
  }

  private func captureResults(query: String) -> [SearchResultDTO] {
    fetchCaptures().compactMap { capture in
      let text = [
        capture.id.uuidString,
        capture.title ?? "",
        capture.text,
        capture.notes ?? "",
        capture.links.joined(separator: " "),
        capture.project?.name ?? "",
        capture.subreddits.map(\.name).joined(separator: " "),
      ].joined(separator: " ")
      guard text.lowercased().contains(query) else { return nil }
      return SearchResultDTO(
        kind: "capture",
        id: capture.id.uuidString,
        title: capture.title ?? capture.text,
        subtitle: capture.status.rawValue)
    }
  }

  private func eventResults(query: String) -> [SearchResultDTO] {
    fetchEvents().compactMap { event in
      let text = [
        event.id.uuidString,
        event.name,
        event.subreddit?.name ?? "",
        event.rrule ?? "",
        event.generationKey ?? "",
      ].joined(separator: " ")
      guard text.lowercased().contains(query) else { return nil }
      let source = event.isGeneratedFromHeuristics ? "generated" : "manual"
      return SearchResultDTO(
        kind: "event",
        id: event.id.uuidString,
        title: event.name,
        subtitle: "\(source) \(event.isActive ? "active" : "inactive")")
    }
  }

  private func peakPresetResults(query: String) -> [SearchResultDTO] {
    SubredditPeakSelection.presets.compactMap { preset in
      let text = [preset.label, preset.days.joined(separator: " "), preset.localHours.map(String.init).joined(separator: " ")]
        .joined(separator: " ")
      guard text.lowercased().contains(query) else { return nil }
      return SearchResultDTO(
        kind: "peakPreset",
        id: preset.label,
        title: preset.label,
        subtitle: "\(preset.days.joined(separator: ",")) @ \(preset.localHours.map(String.init).joined(separator: ","))")
    }
  }

  private func fetchCaptures() -> [Capture] {
    let descriptor = FetchDescriptor<Capture>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
    return (try? context.fetch(descriptor)) ?? []
  }

  private func fetchProjects() -> [Project] {
    let descriptor = FetchDescriptor<Project>(sortBy: [SortDescriptor(\.name)])
    return (try? context.fetch(descriptor)) ?? []
  }

  private func fetchSubreddits() -> [Subreddit] {
    let descriptor = FetchDescriptor<Subreddit>(sortBy: [SortDescriptor(\.sortOrder)])
    return (try? context.fetch(descriptor)) ?? []
  }

  private func fetchEvents() -> [SubredditEvent] {
    let descriptor = FetchDescriptor<SubredditEvent>(sortBy: [
      SortDescriptor(\.oneOffDate),
      SortDescriptor(\.name),
    ])
    return (try? context.fetch(descriptor)) ?? []
  }
}
