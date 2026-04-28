import Foundation
import SwiftData
import Testing
@testable import RedditReminder

private func makeBackupContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
        for: Project.self, Capture.self, Subreddit.self, SubredditEvent.self,
        configurations: config
    )
}

@Test @MainActor func backupRoundTripsDataAndSettings() throws {
    let sourceContainer = try makeBackupContainer()
    let sourceContext = ModelContext(sourceContainer)
    let suiteName = "BackupTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let project = Project(name: "Launch", projectDescription: "Release plan", color: "#FF4500")
    project.archived = true
    sourceContext.insert(project)

    let subreddit = Subreddit(
        name: "r/SwiftUI",
        sortOrder: 4,
        peakDaysOverride: ["mon", "fri"],
        peakHoursUtcOverride: [15, 18]
    )
    sourceContext.insert(subreddit)

    let event = SubredditEvent(
        name: "Weekly thread",
        subreddit: subreddit,
        rrule: "FREQ=WEEKLY;BYDAY=MO",
        recurrenceHour: 15,
        recurrenceMinute: 30,
        recurrenceTimeZoneIdentifier: "America/Phoenix",
        reminderLeadMinutes: 30,
        isGeneratedFromHeuristics: true,
        generationKey: "r/SwiftUI:mon:15"
    )
    sourceContext.insert(event)

    let capture = Capture(
        text: "Post draft",
        notes: "Tighten title",
        links: ["https://example.com"],
        mediaRefs: ["image.png"],
        project: project,
        subreddits: [subreddit]
    )
    capture.markAsPosted()
    sourceContext.insert(capture)
    try sourceContext.save()

    defaults.set(project.id.uuidString, forKey: SettingsKey.defaultProjectId)
    defaults.set(30, forKey: SettingsKey.defaultLeadTimeMinutes)
    defaults.set(false, forKey: SettingsKey.notificationsEnabled)
    defaults.set(KeyboardShortcutConfig.customIdentifier, forKey: SettingsKey.globalShortcutIdentifier)
    defaults.set(35, forKey: SettingsKey.globalShortcutKeyCode)

    let service = BackupService()
    let data = try service.exportBackup(from: sourceContext, defaults: defaults)

    let destinationContainer = try makeBackupContainer()
    let destinationContext = ModelContext(destinationContainer)
    let old = Subreddit(name: "r/Old")
    destinationContext.insert(old)
    try destinationContext.save()

    try service.importBackup(from: data, into: destinationContext, defaults: defaults)

    let projects = try destinationContext.fetch(FetchDescriptor<Project>())
    let subreddits = try destinationContext.fetch(FetchDescriptor<Subreddit>())
    let events = try destinationContext.fetch(FetchDescriptor<SubredditEvent>())
    let captures = try destinationContext.fetch(FetchDescriptor<Capture>())

    #expect(projects.count == 1)
    #expect(projects[0].id == project.id)
    #expect(projects[0].archived)
    #expect(subreddits.count == 1)
    #expect(subreddits[0].peakHoursUtcOverride == [15, 18])
    #expect(events.count == 1)
    #expect(events[0].subreddit?.id == subreddit.id)
    #expect(events[0].isGeneratedFromHeuristics)
    #expect(captures.count == 1)
    #expect(captures[0].project?.id == project.id)
    #expect(captures[0].subreddits.map(\.id) == [subreddit.id])
    #expect(captures[0].status == .posted)
    #expect(defaults.string(forKey: SettingsKey.defaultProjectId) == project.id.uuidString)
    #expect(defaults.integer(forKey: SettingsKey.defaultLeadTimeMinutes) == 30)
}

@Test @MainActor func backupImportRejectsUnsupportedVersion() throws {
    let container = try makeBackupContainer()
    let context = ModelContext(container)
    let data = #"{"version":99,"exportedAt":0,"settings":{},"projects":[],"subreddits":[],"events":[],"captures":[]}"#
        .data(using: .utf8)!

    #expect(throws: BackupError.unsupportedVersion(99)) {
        try BackupService().importBackup(from: data, into: context)
    }
}

@Test @MainActor func backupImportRejectsMissingRelationships() throws {
    let container = try makeBackupContainer()
    let context = ModelContext(container)
    context.insert(Subreddit(name: "r/Existing"))
    try context.save()

    let missing = UUID()
    let backup = AppBackup(
        settings: BackupSettings(),
        projects: [],
        subreddits: [],
        events: [
            BackupSubredditEvent(
                id: UUID(),
                name: "Broken",
                subredditId: missing,
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
    let data = try JSONEncoder().encode(backup)

    #expect(throws: BackupError.missingRelationship(missing.uuidString)) {
        try BackupService().importBackup(from: data, into: context)
    }
    #expect(try context.fetchCount(FetchDescriptor<Subreddit>()) == 1)
}
