import Testing
import SwiftData
@testable import RedditReminder

@Test @MainActor func createCaptureWithRelationships() throws {
    let container = try makeCRUDContainer()
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
    let container = try makeCRUDContainer()
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
    let container = try makeCRUDContainer()
    let context = ModelContext(container)

    let sub = Subreddit(name: "r/Test")
    context.insert(sub)
    let capture = Capture(text: "Temporary", subreddits: [sub])
    context.insert(capture)
    try context.save()

    context.delete(capture)
    try context.save()

    #expect(try context.fetchCount(FetchDescriptor<Capture>()) == 0)
    #expect(try context.fetchCount(FetchDescriptor<Subreddit>()) == 1)
}
