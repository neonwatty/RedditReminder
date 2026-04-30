import SwiftData
import Testing
@testable import RedditReminder

@Test @MainActor func titleOnlyCapturePersists() throws {
    let container = try makeEdgeCaseContainer()
    let context = ModelContext(container)

    let subreddit = Subreddit(name: "r/TitleOnly")
    let capture = Capture(title: "Title only capture", text: "", subreddits: [subreddit])
    context.insert(subreddit)
    context.insert(capture)
    try context.save()

    let fetched = try #require(try context.fetch(FetchDescriptor<Capture>()).first)
    #expect(fetched.title == "Title only capture")
    #expect(fetched.text == "")
    #expect(fetched.subreddits.map(\.name) == ["r/TitleOnly"])
}

@Test @MainActor func bodyOnlyCapturePersists() throws {
    let container = try makeEdgeCaseContainer()
    let context = ModelContext(container)

    let subreddit = Subreddit(name: "r/BodyOnly")
    let capture = Capture(text: "Body only capture", subreddits: [subreddit])
    context.insert(subreddit)
    context.insert(capture)
    try context.save()

    let fetched = try #require(try context.fetch(FetchDescriptor<Capture>()).first)
    #expect(fetched.title == nil)
    #expect(fetched.text == "Body only capture")
    #expect(fetched.subreddits.map(\.name) == ["r/BodyOnly"])
}

@Test @MainActor func longTitleAndBodyPersistUnchanged() throws {
    let container = try makeEdgeCaseContainer()
    let context = ModelContext(container)

    let longTitle = String(repeating: "Launch update with detailed context ", count: 20)
    let longBody = String(repeating: "This is a longer body paragraph for edge-case QA. ", count: 80)
    let capture = Capture(title: longTitle, text: longBody)
    context.insert(capture)
    try context.save()

    let fetched = try #require(try context.fetch(FetchDescriptor<Capture>()).first)
    #expect(fetched.title == longTitle)
    #expect(fetched.text == longBody)
}

@Test @MainActor func captureAssignedToMultipleSubredditsPersists() throws {
    let container = try makeEdgeCaseContainer()
    let context = ModelContext(container)

    let first = Subreddit(name: "r/SideProject", sortOrder: 0)
    let second = Subreddit(name: "r/SwiftUI", sortOrder: 1)
    let third = Subreddit(name: "r/IndieDev", sortOrder: 2)
    let capture = Capture(
        title: "Multi-subreddit capture",
        text: "Post body",
        subreddits: [first, second, third]
    )
    context.insert(first)
    context.insert(second)
    context.insert(third)
    context.insert(capture)
    try context.save()

    let fetched = try #require(try context.fetch(FetchDescriptor<Capture>()).first)
    #expect(fetched.subreddits.map(\.name).sorted() == [
        "r/IndieDev",
        "r/SideProject",
        "r/SwiftUI",
    ])
}
