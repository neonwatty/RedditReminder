import Foundation
import Testing
import SwiftData
@testable import RedditReminder

@Test @MainActor func createRecurringEvent() throws {
    let container = try makeCRUDContainer()
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
    let container = try makeCRUDContainer()
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
    let container = try makeCRUDContainer()
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
