import SwiftData
import Testing

@testable import RedditReminder

@Test @MainActor func createSubreddit() throws {
  let container = try makeCRUDContainer()
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
  let container = try makeCRUDContainer()
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

@Test @MainActor func updateSubredditPostingChecklist() throws {
  let container = try makeCRUDContainer()
  let context = ModelContext(container)

  let sub = Subreddit(name: "r/Test", postingChecklist: "Use the weekly thread.")
  context.insert(sub)
  try context.save()

  sub.postingChecklist = "Add flair after Reddit opens.\nNo direct promo links."
  try context.save()

  let fetched = try context.fetch(FetchDescriptor<Subreddit>())
  #expect(fetched[0].postingChecklist == "Add flair after Reddit opens.\nNo direct promo links.")
}

@Test @MainActor func deleteSubredditCascadesEvents() throws {
  let container = try makeCRUDContainer()
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
  let container = try makeCRUDContainer()
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

@Test @MainActor func subredditCapturesBacklink() throws {
  let container = try makeCRUDContainer()
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
  let container = try makeCRUDContainer()
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
