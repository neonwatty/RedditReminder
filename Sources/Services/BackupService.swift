import Foundation
import SwiftData

enum BackupError: Error, Equatable, LocalizedError {
    case unsupportedVersion(Int)
    case missingRelationship(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let version):
            return "Unsupported backup version \(version)."
        case .missingRelationship(let id):
            return "Backup references missing item \(id)."
        }
    }
}

struct AppBackup: Codable, Equatable {
    var version: Int = 1
    var exportedAt: Date = Date()
    var settings: BackupSettings
    var projects: [BackupProject]
    var subreddits: [BackupSubreddit]
    var events: [BackupSubredditEvent]
    var captures: [BackupCapture]
}

struct BackupSettings: Codable, Equatable {
    var defaultProjectId: String?
    var defaultLeadTimeMinutes: Int?
    var notificationsEnabled: Bool?
    var nudgeWhenEmpty: Bool?
    var globalShortcutIdentifier: String?
    var globalShortcutKeyCode: Int?
    var globalShortcutModifiers: Int?
    var globalShortcutDisplay: String?

    init(
        defaultProjectId: String? = nil,
        defaultLeadTimeMinutes: Int? = nil,
        notificationsEnabled: Bool? = nil,
        nudgeWhenEmpty: Bool? = nil,
        globalShortcutIdentifier: String? = nil,
        globalShortcutKeyCode: Int? = nil,
        globalShortcutModifiers: Int? = nil,
        globalShortcutDisplay: String? = nil
    ) {
        self.defaultProjectId = defaultProjectId
        self.defaultLeadTimeMinutes = defaultLeadTimeMinutes
        self.notificationsEnabled = notificationsEnabled
        self.nudgeWhenEmpty = nudgeWhenEmpty
        self.globalShortcutIdentifier = globalShortcutIdentifier
        self.globalShortcutKeyCode = globalShortcutKeyCode
        self.globalShortcutModifiers = globalShortcutModifiers
        self.globalShortcutDisplay = globalShortcutDisplay
    }
}

struct BackupProject: Codable, Equatable {
    var id: UUID
    var name: String
    var projectDescription: String?
    var color: String?
    var archived: Bool
    var createdAt: Date
}

struct BackupSubreddit: Codable, Equatable {
    var id: UUID
    var name: String
    var sortOrder: Int
    var peakDaysOverride: [String]?
    var peakHoursUtcOverride: [Int]?
}

struct BackupSubredditEvent: Codable, Equatable {
    var id: UUID
    var name: String
    var subredditId: UUID?
    var rrule: String?
    var oneOffDate: Date?
    var recurrenceHour: Int?
    var recurrenceMinute: Int?
    var recurrenceTimeZoneIdentifier: String?
    var reminderLeadMinutes: Int
    var isActive: Bool
    var isGeneratedFromHeuristics: Bool
    var generationKey: String?
}

struct BackupCapture: Codable, Equatable {
    var id: UUID
    var text: String
    var notes: String?
    var links: [String]
    var mediaRefs: [String]
    var status: CaptureStatus
    var createdAt: Date
    var postedAt: Date?
    var projectId: UUID?
    var subredditIds: [UUID]
}

@MainActor
struct BackupService {
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()
    }

    func exportBackup(from context: ModelContext, defaults: UserDefaults = .standard) throws -> Data {
        let backup = AppBackup(
            settings: BackupSettings(
                defaultProjectId: defaults.string(forKey: SettingsKey.defaultProjectId),
                defaultLeadTimeMinutes: defaults.object(forKey: SettingsKey.defaultLeadTimeMinutes) as? Int,
                notificationsEnabled: defaults.object(forKey: SettingsKey.notificationsEnabled) as? Bool,
                nudgeWhenEmpty: defaults.object(forKey: SettingsKey.nudgeWhenEmpty) as? Bool,
                globalShortcutIdentifier: defaults.string(forKey: SettingsKey.globalShortcutIdentifier),
                globalShortcutKeyCode: defaults.object(forKey: SettingsKey.globalShortcutKeyCode) as? Int,
                globalShortcutModifiers: defaults.object(forKey: SettingsKey.globalShortcutModifiers) as? Int,
                globalShortcutDisplay: defaults.string(forKey: SettingsKey.globalShortcutDisplay)
            ),
            projects: try context.fetch(FetchDescriptor<Project>()).map { BackupProject(project: $0) },
            subreddits: try context.fetch(FetchDescriptor<Subreddit>()).map { BackupSubreddit(subreddit: $0) },
            events: try context.fetch(FetchDescriptor<SubredditEvent>()).map { BackupSubredditEvent(event: $0) },
            captures: try context.fetch(FetchDescriptor<Capture>()).map { BackupCapture(capture: $0) }
        )
        return try encoder.encode(backup)
    }

    func importBackup(
        from data: Data,
        into context: ModelContext,
        defaults: UserDefaults = .standard,
        mediaStore: MediaStore? = nil
    ) throws {
        let backup = try decoder.decode(AppBackup.self, from: data)
        guard backup.version == 1 else { throw BackupError.unsupportedVersion(backup.version) }
        try validate(backup)

        try clearData(in: context)

        var projectsById: [UUID: Project] = [:]
        var subredditsById: [UUID: Subreddit] = [:]

        for item in backup.projects {
            let project = Project(name: item.name, projectDescription: item.projectDescription, color: item.color)
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
                peakHoursUtcOverride: item.peakHoursUtcOverride
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
                text: item.text,
                notes: item.notes,
                links: item.links,
                mediaRefs: restoredMediaRefs(from: item, mediaStore: mediaStore),
                project: item.projectId.flatMap { projectsById[$0] },
                subreddits: subreddits
            )
            capture.id = item.id
            capture.status = item.status
            capture.createdAt = item.createdAt
            capture.postedAt = item.postedAt
            context.insert(capture)
        }

        applySettings(backup.settings, to: defaults)
        try context.save()
    }

    private func clearData(in context: ModelContext) throws {
        for capture in try context.fetch(FetchDescriptor<Capture>()) { context.delete(capture) }
        for event in try context.fetch(FetchDescriptor<SubredditEvent>()) { context.delete(event) }
        for project in try context.fetch(FetchDescriptor<Project>()) { context.delete(project) }
        for subreddit in try context.fetch(FetchDescriptor<Subreddit>()) { context.delete(subreddit) }
        try context.save()
    }

    private func validate(_ backup: AppBackup) throws {
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

    private func restoredMediaRefs(from capture: BackupCapture, mediaStore: MediaStore?) -> [String] {
        guard let mediaStore else { return capture.mediaRefs }
        return capture.mediaRefs.filter { mediaStore.exists(captureId: capture.id, ref: $0) }
    }

    private func applySettings(_ settings: BackupSettings, to defaults: UserDefaults) {
        set(settings.defaultProjectId, forKey: SettingsKey.defaultProjectId, defaults: defaults)
        set(settings.defaultLeadTimeMinutes, forKey: SettingsKey.defaultLeadTimeMinutes, defaults: defaults)
        set(settings.notificationsEnabled, forKey: SettingsKey.notificationsEnabled, defaults: defaults)
        set(settings.nudgeWhenEmpty, forKey: SettingsKey.nudgeWhenEmpty, defaults: defaults)
        set(settings.globalShortcutIdentifier, forKey: SettingsKey.globalShortcutIdentifier, defaults: defaults)
        set(settings.globalShortcutKeyCode, forKey: SettingsKey.globalShortcutKeyCode, defaults: defaults)
        set(settings.globalShortcutModifiers, forKey: SettingsKey.globalShortcutModifiers, defaults: defaults)
        set(settings.globalShortcutDisplay, forKey: SettingsKey.globalShortcutDisplay, defaults: defaults)
    }

    private func set(_ value: Any?, forKey key: String, defaults: UserDefaults) {
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}
