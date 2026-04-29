import Foundation
import SwiftData
import Testing
@testable import RedditReminder

@Test @MainActor func backupImportFailurePreservesExistingSettings() throws {
    let container = try makeBackupContainer()
    let context = ModelContext(container)
    let suiteName = "BackupImportTransactionTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    defaults.set("existing-project", forKey: SettingsKey.defaultProjectId)
    defaults.set(30, forKey: SettingsKey.defaultLeadTimeMinutes)
    defaults.set(false, forKey: SettingsKey.notificationsEnabled)

    let backup = AppBackup(
        settings: BackupSettings(
            defaultProjectId: "incoming-project",
            defaultLeadTimeMinutes: 120,
            notificationsEnabled: true
        ),
        projects: [],
        subreddits: [],
        events: [
            BackupSubredditEvent(
                id: UUID(),
                name: "Broken",
                subredditId: UUID(),
                rrule: nil,
                oneOffDate: nil,
                recurrenceHour: nil,
                recurrenceMinute: nil,
                recurrenceTimeZoneIdentifier: nil,
                reminderLeadMinutes: 60,
                isActive: true,
                isGeneratedFromHeuristics: false,
                generationKey: nil
            )
        ],
        captures: []
    )

    #expect(throws: BackupError.self) {
        try BackupService().importBackup(
            from: JSONEncoder().encode(backup),
            into: context,
            defaults: defaults
        )
    }
    #expect(defaults.string(forKey: SettingsKey.defaultProjectId) == "existing-project")
    #expect(defaults.integer(forKey: SettingsKey.defaultLeadTimeMinutes) == 30)
    #expect(defaults.bool(forKey: SettingsKey.notificationsEnabled) == false)
}

@Test @MainActor func backupImportFailurePreservesExistingData() throws {
    let container = try makeBackupContainer()
    let context = ModelContext(container)
    let existing = Subreddit(name: "r/Existing")
    context.insert(existing)
    try context.save()

    let backup = AppBackup(
        settings: BackupSettings(),
        projects: [],
        subreddits: [],
        events: [],
        captures: [
            BackupCapture(
                id: UUID(),
                text: "Broken capture",
                notes: nil,
                links: [],
                mediaRefs: [],
                status: .queued,
                createdAt: Date(),
                postedAt: nil,
                projectId: nil,
                subredditIds: [UUID()]
            )
        ]
    )

    #expect(throws: BackupError.self) {
        try BackupService().importBackup(from: JSONEncoder().encode(backup), into: context)
    }
    let subreddits = try context.fetch(FetchDescriptor<Subreddit>())
    #expect(subreddits.map(\.name) == ["r/Existing"])
}
