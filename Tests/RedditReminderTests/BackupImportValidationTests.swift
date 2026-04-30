import Foundation
import SwiftData
import Testing
@testable import RedditReminder

@Test @MainActor func backupImportRejectsUnsupportedVersion() throws {
    let container = try makeBackupContainer()
    let context = ModelContext(container)
    let data = #"{"version":99,"exportedAt":0,"settings":{},"projects":[],"subreddits":[],"events":[],"captures":[]}"#
        .data(using: .utf8)!

    #expect(throws: BackupError.unsupportedVersion(99)) {
        try BackupService().importBackup(from: data, into: context)
    }
}

@Test @MainActor func backupPreviewRejectsInvalidBackupWithoutClearingData() throws {
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

    #expect(throws: BackupError.missingRelationship(missing.uuidString)) {
        _ = try BackupService().previewBackup(from: JSONEncoder().encode(backup))
    }
    #expect(try context.fetchCount(FetchDescriptor<Subreddit>()) == 1)
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

@Test @MainActor func backupImportRejectsDuplicateProjectIdsBeforeClearingData() throws {
    let container = try makeBackupContainer()
    let context = ModelContext(container)
    context.insert(Project(name: "Existing"))
    try context.save()

    let duplicateId = UUID()
    let backup = AppBackup(
        settings: BackupSettings(),
        projects: [
            BackupProject(
                id: duplicateId,
                name: "First",
                projectDescription: nil,
                color: nil,
                archived: false,
                createdAt: Date()
            ),
            BackupProject(
                id: duplicateId,
                name: "Second",
                projectDescription: nil,
                color: nil,
                archived: false,
                createdAt: Date()
            )
        ],
        subreddits: [],
        events: [],
        captures: []
    )

    #expect(throws: BackupError.duplicateId(duplicateId.uuidString)) {
        try BackupService().importBackup(from: JSONEncoder().encode(backup), into: context)
    }
    #expect(try context.fetchCount(FetchDescriptor<Project>()) == 1)
}

@Test @MainActor func backupImportRejectsDuplicateSubredditIdsBeforeClearingData() throws {
    let container = try makeBackupContainer()
    let context = ModelContext(container)
    context.insert(Subreddit(name: "r/Existing"))
    try context.save()

    let duplicateId = UUID()
    let backup = AppBackup(
        settings: BackupSettings(),
        projects: [],
        subreddits: [
            BackupSubreddit(
                id: duplicateId,
                name: "r/First",
                sortOrder: 0,
                peakDaysOverride: nil,
                peakHoursUtcOverride: nil
            ),
            BackupSubreddit(
                id: duplicateId,
                name: "r/Second",
                sortOrder: 1,
                peakDaysOverride: nil,
                peakHoursUtcOverride: nil
            )
        ],
        events: [],
        captures: []
    )

    #expect(throws: BackupError.duplicateId(duplicateId.uuidString)) {
        try BackupService().importBackup(from: JSONEncoder().encode(backup), into: context)
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
