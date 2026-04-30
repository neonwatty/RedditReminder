import Testing
import Foundation
import SwiftData
@testable import RedditReminder

@Test @MainActor func backupRoundTripPreservesAllFields() throws {
    let container = try makeCRUDContainer()
    let context = container.mainContext

    // Seed data
    let project = Project(name: "Launch", projectDescription: "Q2 launch", color: "blue")
    project.archived = false
    context.insert(project)

    let sub1 = Subreddit(name: "r/webdev", sortOrder: 0, postingChecklist: "Check rules\nAdd flair")
    let sub2 = Subreddit(name: "r/SideProject", sortOrder: 1)
    context.insert(sub1)
    context.insert(sub2)

    let event1 = SubredditEvent(
        name: "Weekly",
        subreddit: sub1,
        rrule: "FREQ=WEEKLY;BYDAY=MO",
        recurrenceHour: 10,
        recurrenceMinute: 30,
        recurrenceTimeZoneIdentifier: "America/New_York",
        reminderLeadMinutes: 30,
        isGeneratedFromHeuristics: true,
        generationKey: "r/webdev-weekday"
    )
    let event2 = SubredditEvent(
        name: "Launch Day",
        subreddit: sub2,
        oneOffDate: Date(timeIntervalSince1970: 1_800_000_000),
        reminderLeadMinutes: 60
    )
    context.insert(event1)
    context.insert(event2)

    let capture1 = Capture(
        title: "Post Title",
        text: "Post body text",
        notes: "Remember to add images",
        links: ["https://example.com", "https://github.com"],
        mediaRefs: ["img1.png", "img2.jpg"],
        project: project,
        subreddits: [sub1, sub2]
    )
    let capture2 = Capture(text: "Quick thought", subreddits: [sub1])
    capture2.markSubredditAsPosted(sub1.id)

    let capture3 = Capture(text: "Fully posted", subreddits: [sub1, sub2])
    capture3.markAsPosted(postedURL: "https://reddit.com/r/webdev/123")

    context.insert(capture1)
    context.insert(capture2)
    context.insert(capture3)
    try context.save()

    // Snapshot original state
    let originalProjectIds = [project.id]
    let originalSubIds = [sub1.id, sub2.id]
    let originalEventIds = [event1.id, event2.id]
    let originalCaptureIds = [capture1.id, capture2.id, capture3.id]

    // Export
    let service = BackupService()
    let data = try service.exportBackup(from: context)

    // Wipe
    for c in try context.fetch(FetchDescriptor<Capture>()) { context.delete(c) }
    for e in try context.fetch(FetchDescriptor<SubredditEvent>()) { context.delete(e) }
    for p in try context.fetch(FetchDescriptor<Project>()) { context.delete(p) }
    for s in try context.fetch(FetchDescriptor<Subreddit>()) { context.delete(s) }
    try context.save()

    #expect(try context.fetchCount(FetchDescriptor<Capture>()) == 0)

    // Import
    let suiteName = "RoundTrip-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    try service.importBackup(from: data, into: context, defaults: defaults)

    // Verify projects
    let restoredProjects = try context.fetch(FetchDescriptor<Project>())
    #expect(restoredProjects.count == 1)
    let rp = restoredProjects[0]
    #expect(rp.id == originalProjectIds[0])
    #expect(rp.name == "Launch")
    #expect(rp.projectDescription == "Q2 launch")
    #expect(rp.color == "blue")
    #expect(rp.archived == false)

    // Verify subreddits
    let restoredSubs = try context.fetch(FetchDescriptor<Subreddit>())
    #expect(restoredSubs.count == 2)
    let rs1 = restoredSubs.first { $0.id == originalSubIds[0] }!
    #expect(rs1.name == "r/webdev")
    #expect(rs1.sortOrder == 0)
    #expect(rs1.postingChecklist == "Check rules\nAdd flair")
    let rs2 = restoredSubs.first { $0.id == originalSubIds[1] }!
    #expect(rs2.name == "r/SideProject")

    // Verify events
    let restoredEvents = try context.fetch(FetchDescriptor<SubredditEvent>())
    #expect(restoredEvents.count == 2)
    let re1 = restoredEvents.first { $0.id == originalEventIds[0] }!
    #expect(re1.name == "Weekly")
    #expect(re1.rrule == "FREQ=WEEKLY;BYDAY=MO")
    #expect(re1.recurrenceHour == 10)
    #expect(re1.recurrenceMinute == 30)
    #expect(re1.recurrenceTimeZoneIdentifier == "America/New_York")
    #expect(re1.reminderLeadMinutes == 30)
    #expect(re1.isGeneratedFromHeuristics == true)
    #expect(re1.generationKey == "r/webdev-weekday")
    #expect(re1.subreddit?.id == originalSubIds[0])
    let re2 = restoredEvents.first { $0.id == originalEventIds[1] }!
    #expect(re2.oneOffDate == Date(timeIntervalSince1970: 1_800_000_000))

    // Verify captures
    let restoredCaptures = try context.fetch(FetchDescriptor<Capture>())
    #expect(restoredCaptures.count == 3)

    let rc1 = restoredCaptures.first { $0.id == originalCaptureIds[0] }!
    #expect(rc1.title == "Post Title")
    #expect(rc1.text == "Post body text")
    #expect(rc1.notes == "Remember to add images")
    #expect(rc1.links == ["https://example.com", "https://github.com"])
    #expect(rc1.status == .queued)
    #expect(rc1.project?.id == originalProjectIds[0])
    #expect(Set(rc1.subreddits.map(\.id)) == Set(originalSubIds))
    #expect(rc1.postedSubredditIDs.isEmpty)

    let rc2 = restoredCaptures.first { $0.id == originalCaptureIds[1] }!
    #expect(rc2.status == .queued)
    #expect(rc2.postedSubredditIDs == [originalSubIds[0]])

    let rc3 = restoredCaptures.first { $0.id == originalCaptureIds[2] }!
    #expect(rc3.status == .posted)
    #expect(rc3.postedURL == "https://reddit.com/r/webdev/123")
    #expect(Set(rc3.postedSubredditIDs) == Set(originalSubIds))
}

@Test @MainActor func backupRoundTripEmptyData() throws {
    let container = try makeCRUDContainer()
    let context = container.mainContext

    let service = BackupService()
    let data = try service.exportBackup(from: context)

    let suiteName = "RoundTripEmpty-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let result = try service.importBackup(from: data, into: context, defaults: defaults)

    #expect(result.preview.captures == 0)
    #expect(result.preview.projects == 0)
    #expect(result.preview.subreddits == 0)
    #expect(result.preview.events == 0)
}
