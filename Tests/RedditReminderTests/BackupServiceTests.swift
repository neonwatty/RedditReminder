import AppKit
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

@Test @MainActor func backupImportRejectsCaptureMissingProjectBeforeClearingData() throws {
    let container = try makeBackupContainer()
    let context = ModelContext(container)
    context.insert(Project(name: "Existing"))
    try context.save()

    let missingProject = UUID()
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
                projectId: missingProject,
                subredditIds: []
            )
        ]
    )
    let data = try JSONEncoder().encode(backup)

    #expect(throws: BackupError.missingRelationship(missingProject.uuidString)) {
        try BackupService().importBackup(from: data, into: context)
    }
    #expect(try context.fetchCount(FetchDescriptor<Project>()) == 1)
}

@Test @MainActor func backupImportRejectsCaptureMissingSubredditBeforeClearingData() throws {
    let container = try makeBackupContainer()
    let context = ModelContext(container)
    context.insert(Subreddit(name: "r/Existing"))
    try context.save()

    let missingSubreddit = UUID()
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
                subredditIds: [missingSubreddit]
            )
        ]
    )
    let data = try JSONEncoder().encode(backup)

    #expect(throws: BackupError.missingRelationship(missingSubreddit.uuidString)) {
        try BackupService().importBackup(from: data, into: context)
    }
    #expect(try context.fetchCount(FetchDescriptor<Subreddit>()) == 1)
}

@Test @MainActor func backupImportClearsOmittedSettings() throws {
    let container = try makeBackupContainer()
    let context = ModelContext(container)
    let suiteName = "BackupTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    defaults.set("stale-project", forKey: SettingsKey.defaultProjectId)
    defaults.set(120, forKey: SettingsKey.defaultLeadTimeMinutes)
    defaults.set(false, forKey: SettingsKey.notificationsEnabled)
    defaults.set(true, forKey: SettingsKey.nudgeWhenEmpty)
    defaults.set("cmd-option-r", forKey: SettingsKey.globalShortcutIdentifier)
    defaults.set(15, forKey: SettingsKey.globalShortcutKeyCode)
    defaults.set(123, forKey: SettingsKey.globalShortcutModifiers)
    defaults.set("Old", forKey: SettingsKey.globalShortcutDisplay)

    let backup = AppBackup(
        settings: BackupSettings(),
        projects: [],
        subreddits: [],
        events: [],
        captures: []
    )
    let data = try JSONEncoder().encode(backup)

    try BackupService().importBackup(from: data, into: context, defaults: defaults)

    #expect(defaults.object(forKey: SettingsKey.defaultProjectId) == nil)
    #expect(defaults.object(forKey: SettingsKey.defaultLeadTimeMinutes) == nil)
    #expect(defaults.object(forKey: SettingsKey.notificationsEnabled) == nil)
    #expect(defaults.object(forKey: SettingsKey.nudgeWhenEmpty) == nil)
    #expect(defaults.object(forKey: SettingsKey.globalShortcutIdentifier) == nil)
    #expect(defaults.object(forKey: SettingsKey.globalShortcutKeyCode) == nil)
    #expect(defaults.object(forKey: SettingsKey.globalShortcutModifiers) == nil)
    #expect(defaults.object(forKey: SettingsKey.globalShortcutDisplay) == nil)
}

@Test @MainActor func backupImportDropsMissingMediaRefsWhenMediaStoreProvided() throws {
    let container = try makeBackupContainer()
    let context = ModelContext(container)
    let subredditId = UUID()
    let captureId = UUID()
    let backup = AppBackup(
        settings: BackupSettings(),
        projects: [],
        subreddits: [
            BackupSubreddit(
                id: subredditId,
                name: "r/SwiftUI",
                sortOrder: 0,
                peakDaysOverride: nil,
                peakHoursUtcOverride: nil
            )
        ],
        events: [],
        captures: [
            BackupCapture(
                id: captureId,
                text: "With missing media",
                notes: nil,
                links: [],
                mediaRefs: ["missing.png"],
                status: .queued,
                createdAt: Date(),
                postedAt: nil,
                projectId: nil,
                subredditIds: [subredditId]
            )
        ]
    )
    let mediaStore = MediaStore(rootDir: temporaryBackupMediaRoot())

    try BackupService().importBackup(
        from: JSONEncoder().encode(backup),
        into: context,
        mediaStore: mediaStore
    )

    let captures = try context.fetch(FetchDescriptor<Capture>())
    #expect(captures.count == 1)
    #expect(captures[0].mediaRefs.isEmpty)
}

@Test @MainActor func backupImportPreservesExistingMediaRefsWhenMediaStoreProvided() throws {
    let container = try makeBackupContainer()
    let context = ModelContext(container)
    let subredditId = UUID()
    let captureId = UUID()
    let mediaStore = MediaStore(rootDir: temporaryBackupMediaRoot())
    let ref = try mediaStore.save(image: backupTestImage(), captureId: captureId, fileName: "present.png")
    let backup = AppBackup(
        settings: BackupSettings(),
        projects: [],
        subreddits: [
            BackupSubreddit(
                id: subredditId,
                name: "r/SwiftUI",
                sortOrder: 0,
                peakDaysOverride: nil,
                peakHoursUtcOverride: nil
            )
        ],
        events: [],
        captures: [
            BackupCapture(
                id: captureId,
                text: "With present media",
                notes: nil,
                links: [],
                mediaRefs: [ref, "missing.png"],
                status: .queued,
                createdAt: Date(),
                postedAt: nil,
                projectId: nil,
                subredditIds: [subredditId]
            )
        ]
    )

    try BackupService().importBackup(
        from: JSONEncoder().encode(backup),
        into: context,
        mediaStore: mediaStore
    )

    let captures = try context.fetch(FetchDescriptor<Capture>())
    #expect(captures.count == 1)
    #expect(captures[0].mediaRefs == [ref])
}

private func temporaryBackupMediaRoot() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
}

private func backupTestImage() -> NSImage {
    let image = NSImage(size: NSSize(width: 32, height: 32))
    image.lockFocus()
    NSColor.systemBlue.setFill()
    NSRect(x: 0, y: 0, width: 32, height: 32).fill()
    image.unlockFocus()
    return image
}
