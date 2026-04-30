import Foundation
import SwiftData

@MainActor
struct BackupService {
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder

  init() {
    encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    decoder = JSONDecoder()
  }

  func exportBackup(
    from context: ModelContext,
    defaults: UserDefaults = .standard,
    mediaStore: MediaStore? = nil
  ) throws -> Data {
    let captures = try context.fetch(FetchDescriptor<Capture>())
    let backup = AppBackup(
      settings: BackupSettingsPersistence.snapshot(from: defaults),
      projects: try context.fetch(FetchDescriptor<Project>()).map { BackupProject(project: $0) },
      subreddits: try context.fetch(FetchDescriptor<Subreddit>()).map {
        BackupSubreddit(subreddit: $0)
      },
      events: try context.fetch(FetchDescriptor<SubredditEvent>()).map {
        BackupSubredditEvent(event: $0)
      },
      captures: captures.map { BackupCapture(capture: $0) },
      mediaFiles: try mediaFiles(from: captures, mediaStore: mediaStore)
    )
    return try encoder.encode(backup)
  }

  func previewBackup(from data: Data) throws -> BackupPreview {
    let backup = try decodedValidatedBackup(from: data)
    return preview(for: backup)
  }

  @discardableResult
  func importBackup(
    from data: Data,
    into context: ModelContext,
    defaults: UserDefaults = .standard,
    mediaStore: MediaStore? = nil
  ) throws -> BackupImportResult {
    let backup = try decodedValidatedBackup(from: data)
    let preview = preview(for: backup)

    var restoredMedia: Set<MediaIdentity> = []
    do {
      restoredMedia = try restoreEmbeddedMedia(from: backup, mediaStore: mediaStore)
      try clearData(in: context)
      try insert(backup, into: context, mediaStore: mediaStore, restoredMedia: restoredMedia)
      try context.save()
    } catch {
      context.rollback()
      deleteMedia(restoredMedia, mediaStore: mediaStore)
      throw error
    }
    BackupSettingsPersistence.apply(backup.settings, to: defaults)
    return BackupImportResult(preview: preview)
  }

  private func decodedValidatedBackup(from data: Data) throws -> AppBackup {
    let backup = try decoder.decode(AppBackup.self, from: data)
    guard backup.version == 1 else { throw BackupError.unsupportedVersion(backup.version) }
    try validate(backup)
    return backup
  }

  private func preview(for backup: AppBackup) -> BackupPreview {
    BackupPreview(
      projects: backup.projects.count,
      subreddits: backup.subreddits.count,
      events: backup.events.count,
      captures: backup.captures.count,
      embeddedMediaFiles: backup.mediaFiles?.count ?? 0,
      includesSettings: backup.settings.hasAnyValue
    )
  }

  private func clearData(in context: ModelContext) throws {
    for capture in try context.fetch(FetchDescriptor<Capture>()) { context.delete(capture) }
    for event in try context.fetch(FetchDescriptor<SubredditEvent>()) { context.delete(event) }
    for project in try context.fetch(FetchDescriptor<Project>()) { context.delete(project) }
    for subreddit in try context.fetch(FetchDescriptor<Subreddit>()) { context.delete(subreddit) }
  }

  private func insert(
    _ backup: AppBackup,
    into context: ModelContext,
    mediaStore: MediaStore?,
    restoredMedia: Set<MediaIdentity>
  ) throws {
    var projectsById: [UUID: Project] = [:]
    var subredditsById: [UUID: Subreddit] = [:]

    for item in backup.projects {
      let project = Project(
        name: item.name, projectDescription: item.projectDescription, color: item.color)
      project.id = item.id
      project.archived = item.archived
      project.createdAt = item.createdAt
      context.insert(project)
      projectsById[item.id] = project
    }

    for item in backup.subreddits {
      let subreddit = Subreddit(
        name: item.name,
        sortOrder: item.sortOrder,
        peakDaysOverride: item.peakDaysOverride,
        peakHoursUtcOverride: item.peakHoursUtcOverride,
        postingChecklist: item.postingChecklist
      )
      subreddit.id = item.id
      context.insert(subreddit)
      subredditsById[item.id] = subreddit
    }

    for item in backup.events {
      guard let subredditId = item.subredditId, let subreddit = subredditsById[subredditId] else {
        throw BackupError.missingRelationship(item.subredditId?.uuidString ?? item.id.uuidString)
      }
      let event = SubredditEvent(
        name: item.name,
        subreddit: subreddit,
        rrule: item.rrule,
        oneOffDate: item.oneOffDate,
        recurrenceHour: item.recurrenceHour,
        recurrenceMinute: item.recurrenceMinute,
        recurrenceTimeZoneIdentifier: item.recurrenceTimeZoneIdentifier,
        reminderLeadMinutes: item.reminderLeadMinutes,
        isActive: item.isActive,
        isGeneratedFromHeuristics: item.isGeneratedFromHeuristics,
        generationKey: item.generationKey
      )
      event.id = item.id
      context.insert(event)
    }

    for item in backup.captures {
      let subreddits = try item.subredditIds.map { id in
        guard let subreddit = subredditsById[id] else {
          throw BackupError.missingRelationship(id.uuidString)
        }
        return subreddit
      }
      let capture = Capture(
        title: item.title,
        text: item.text,
        notes: item.notes,
        links: item.links,
        mediaRefs: restoredMediaRefs(
          from: item, mediaStore: mediaStore, restoredMedia: restoredMedia),
        project: item.projectId.flatMap { projectsById[$0] },
        subreddits: subreddits
      )
      capture.id = item.id
      capture.status = item.status
      capture.createdAt = item.createdAt
      capture.postedAt = item.postedAt
      capture.postedURL = item.postedURL
      context.insert(capture)
    }
  }

  private func validate(_ backup: AppBackup) throws {
    try validateUniqueIds(backup.projects.map(\.id))
    try validateUniqueIds(backup.subreddits.map(\.id))
    try validateUniqueIds(backup.events.map(\.id))
    try validateUniqueIds(backup.captures.map(\.id))

    let projectIds = Set(backup.projects.map(\.id))
    let subredditIds = Set(backup.subreddits.map(\.id))
    for event in backup.events {
      guard let subredditId = event.subredditId, subredditIds.contains(subredditId) else {
        throw BackupError.missingRelationship(event.subredditId?.uuidString ?? event.id.uuidString)
      }
    }
    for capture in backup.captures {
      if let projectId = capture.projectId, !projectIds.contains(projectId) {
        throw BackupError.missingRelationship(projectId.uuidString)
      }
      for subredditId in capture.subredditIds where !subredditIds.contains(subredditId) {
        throw BackupError.missingRelationship(subredditId.uuidString)
      }
    }
  }

  private func validateUniqueIds(_ ids: [UUID]) throws {
    var seen: Set<UUID> = []
    for id in ids {
      guard seen.insert(id).inserted else {
        throw BackupError.duplicateId(id.uuidString)
      }
    }
  }

}
