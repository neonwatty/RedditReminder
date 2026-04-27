import Testing
import Foundation
import SwiftData
@testable import RedditReminder

/// Creates an in-memory ModelContainer for isolated SwiftData tests.
private func makeContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
        for: Project.self, Capture.self, Subreddit.self, SubredditEvent.self,
        configurations: config
    )
}

// MARK: - Project CRUD

@Test @MainActor func createProject() throws {
    let container = try makeContainer()
    let context = ModelContext(container)

    let project = Project(name: "Bullhorn", projectDescription: "Scheduler app", color: "#FF0000")
    context.insert(project)
    try context.save()

    let fetched = try context.fetch(FetchDescriptor<Project>())
    #expect(fetched.count == 1)
    #expect(fetched[0].name == "Bullhorn")
    #expect(fetched[0].projectDescription == "Scheduler app")
    #expect(fetched[0].color == "#FF0000")
    #expect(fetched[0].archived == false)
}

@Test @MainActor func updateProject() throws {
    let container = try makeContainer()
    let context = ModelContext(container)

    let project = Project(name: "Original")
    context.insert(project)
    try context.save()

    project.name = "Updated"
    project.archived = true
    try context.save()

    let fetched = try context.fetch(FetchDescriptor<Project>())
    #expect(fetched[0].name == "Updated")
    #expect(fetched[0].archived == true)
}

@Test @MainActor func deleteProjectCascadesCaptures() throws {
    let container = try makeContainer()
    let context = ModelContext(container)

    let project = Project(name: "Doomed")
    context.insert(project)
    let capture = Capture(text: "Will be deleted", project: project)
    context.insert(capture)
    try context.save()

    #expect(try context.fetchCount(FetchDescriptor<Capture>()) == 1)

    context.delete(project)
    try context.save()

    #expect(try context.fetchCount(FetchDescriptor<Project>()) == 0)
    #expect(try context.fetchCount(FetchDescriptor<Capture>()) == 0)
}

// MARK: - Subreddit CRUD

@Test @MainActor func createSubreddit() throws {
    let container = try makeContainer()
    let context = ModelContext(container)

    let sub = Subreddit(name: "r/SideProject", sortOrder: 3)
    context.insert(sub)
    try context.save()

    let fetched = try context.fetch(FetchDescriptor<Subreddit>())
    #expect(fetched.count == 1)
    #expect(fetched[0].name == "r/SideProject")
    #expect(fetched[0].sortOrder == 3)
    #expect(fetched[0].events.isEmpty)
}

@Test @MainActor func updateSubredditPeakOverrides() throws {
    let container = try makeContainer()
    let context = ModelContext(container)

    let sub = Subreddit(name: "r/Test")
    context.insert(sub)
    try context.save()

    sub.peakDaysOverride = ["mon", "fri"]
    sub.peakHoursUtcOverride = [14, 15]
    try context.save()

    let fetched = try context.fetch(FetchDescriptor<Subreddit>())
    #expect(fetched[0].peakDaysOverride == ["mon", "fri"])
    #expect(fetched[0].peakHoursUtcOverride == [14, 15])
}

@Test @MainActor func deleteSubredditCascadesEvents() throws {
    let container = try makeContainer()
    let context = ModelContext(container)

    let sub = Subreddit(name: "r/Test")
    context.insert(sub)
    let event = SubredditEvent(name: "Weekly", subreddit: sub, rrule: "FREQ=WEEKLY;BYDAY=SA")
    context.insert(event)
    try context.save()

    #expect(try context.fetchCount(FetchDescriptor<SubredditEvent>()) == 1)

    context.delete(sub)
    try context.save()

    #expect(try context.fetchCount(FetchDescriptor<Subreddit>()) == 0)
    #expect(try context.fetchCount(FetchDescriptor<SubredditEvent>()) == 0)
}

@Test @MainActor func deleteSubredditDoesNotDeleteCaptures() throws {
    let container = try makeContainer()
    let context = ModelContext(container)

    let sub = Subreddit(name: "r/Test")
    context.insert(sub)
    let capture = Capture(text: "Survives", subreddits: [sub])
    context.insert(capture)
    try context.save()

    context.delete(sub)
    try context.save()

    #expect(try context.fetchCount(FetchDescriptor<Subreddit>()) == 0)
    #expect(try context.fetchCount(FetchDescriptor<Capture>()) == 1)
}

// MARK: - SubredditEvent CRUD

@Test @MainActor func createRecurringEvent() throws {
    let container = try makeContainer()
    let context = ModelContext(container)

    let sub = Subreddit(name: "r/Test")
    context.insert(sub)
    let event = SubredditEvent(
        name: "Weekly Post",
        subreddit: sub,
        rrule: "FREQ=WEEKLY;BYDAY=SA",
        reminderLeadMinutes: 30
    )
    context.insert(event)
    try context.save()

    let fetched = try context.fetch(FetchDescriptor<SubredditEvent>())
    #expect(fetched.count == 1)
    #expect(fetched[0].isRecurring)
    #expect(fetched[0].reminderLeadMinutes == 30)
    #expect(fetched[0].subreddit?.name == "r/Test")
}

@Test @MainActor func createOneOffEvent() throws {
    let container = try makeContainer()
    let context = ModelContext(container)

    let sub = Subreddit(name: "r/Test")
    context.insert(sub)
    let futureDate = Date().addingTimeInterval(86400)
    let event = SubredditEvent(name: "Launch Day", subreddit: sub, oneOffDate: futureDate)
    context.insert(event)
    try context.save()

    let fetched = try context.fetch(FetchDescriptor<SubredditEvent>())
    #expect(!fetched[0].isRecurring)
    #expect(fetched[0].oneOffDate != nil)
}

@Test @MainActor func deactivateEvent() throws {
    let container = try makeContainer()
    let context = ModelContext(container)

    let sub = Subreddit(name: "r/Test")
    context.insert(sub)
    let event = SubredditEvent(name: "Weekly", subreddit: sub, rrule: "FREQ=WEEKLY;BYDAY=SA")
    context.insert(event)
    try context.save()

    event.isActive = false
    try context.save()

    let fetched = try context.fetch(FetchDescriptor<SubredditEvent>())
    #expect(fetched[0].isActive == false)
}

// MARK: - Capture CRUD

@Test @MainActor func createCaptureWithRelationships() throws {
    let container = try makeContainer()
    let context = ModelContext(container)

    let project = Project(name: "TestProject")
    context.insert(project)
    let sub1 = Subreddit(name: "r/A")
    let sub2 = Subreddit(name: "r/B")
    context.insert(sub1)
    context.insert(sub2)

    let capture = Capture(
        text: "Multi-sub capture",
        links: ["https://example.com"],
        project: project,
        subreddits: [sub1, sub2]
    )
    context.insert(capture)
    try context.save()

    let fetched = try context.fetch(FetchDescriptor<Capture>())
    #expect(fetched.count == 1)
    #expect(fetched[0].subreddits.count == 2)
    #expect(fetched[0].project?.name == "TestProject")
    #expect(fetched[0].links == ["https://example.com"])
}

@Test @MainActor func markCaptureAsPostedPersists() throws {
    let container = try makeContainer()
    let context = ModelContext(container)

    let capture = Capture(text: "Ship it")
    context.insert(capture)
    try context.save()

    capture.markAsPosted()
    try context.save()

    let fetched = try context.fetch(FetchDescriptor<Capture>())
    #expect(fetched[0].status == .posted)
    #expect(fetched[0].postedAt != nil)
}

@Test @MainActor func deleteCapture() throws {
    let container = try makeContainer()
    let context = ModelContext(container)

    let sub = Subreddit(name: "r/Test")
    context.insert(sub)
    let capture = Capture(text: "Temporary", subreddits: [sub])
    context.insert(capture)
    try context.save()

    context.delete(capture)
    try context.save()

    #expect(try context.fetchCount(FetchDescriptor<Capture>()) == 0)
    // Subreddit survives
    #expect(try context.fetchCount(FetchDescriptor<Subreddit>()) == 1)
}

// MARK: - Multi-model relationships

@Test @MainActor func projectCapturesRelationshipBidirectional() throws {
    let container = try makeContainer()
    let context = ModelContext(container)

    let project = Project(name: "Bullhorn")
    context.insert(project)
    let c1 = Capture(text: "Cap 1", project: project)
    let c2 = Capture(text: "Cap 2", project: project)
    context.insert(c1)
    context.insert(c2)
    try context.save()

    let fetched = try context.fetch(FetchDescriptor<Project>())
    #expect(fetched[0].captures.count == 2)
}

@Test @MainActor func subredditCapturesBacklink() throws {
    let container = try makeContainer()
    let context = ModelContext(container)

    let sub = Subreddit(name: "r/Test")
    context.insert(sub)
    let c1 = Capture(text: "Cap 1", subreddits: [sub])
    let c2 = Capture(text: "Cap 2", subreddits: [sub])
    context.insert(c1)
    context.insert(c2)
    try context.save()

    let fetched = try context.fetch(FetchDescriptor<Subreddit>())
    #expect(fetched[0].captures.count == 2)
}

@Test @MainActor func subredditEventsRelationshipBidirectional() throws {
    let container = try makeContainer()
    let context = ModelContext(container)

    let sub = Subreddit(name: "r/Test")
    context.insert(sub)
    let e1 = SubredditEvent(name: "Weekly", subreddit: sub, rrule: "FREQ=WEEKLY;BYDAY=SA")
    let e2 = SubredditEvent(name: "Daily", subreddit: sub, rrule: "FREQ=DAILY")
    context.insert(e1)
    context.insert(e2)
    try context.save()

    let fetched = try context.fetch(FetchDescriptor<Subreddit>())
    #expect(fetched[0].events.count == 2)
}
