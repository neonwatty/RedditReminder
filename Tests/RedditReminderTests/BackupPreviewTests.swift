import Testing
@testable import RedditReminder

@Test func backupPreviewSummaryPluralizesCountsAndIncludesSettings() {
    let preview = BackupPreview(
        projects: 1,
        subreddits: 2,
        events: 1,
        captures: 1,
        embeddedMediaFiles: 1,
        includesSettings: true
    )

    #expect(preview.importSummary == "1 capture, 1 project, 2 subreddits, 1 reminder, 1 media file, settings")
}

@Test func backupPreviewSummaryOmitsEmptyMediaAndSettings() {
    let preview = BackupPreview(
        projects: 0,
        subreddits: 0,
        events: 0,
        captures: 0,
        embeddedMediaFiles: 0,
        includesSettings: false
    )

    #expect(preview.importSummary == "0 captures, 0 projects, 0 subreddits, 0 reminders")
}
