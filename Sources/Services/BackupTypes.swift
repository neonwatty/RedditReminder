import Foundation

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
