import Foundation
import SwiftData
import Testing

@testable import RedditReminder

@Test @MainActor func plannerEventLoaderFetchesOnlyUpcomingOneOffCandidates() throws {
  let container = try makeCRUDContainer()
  let context = container.mainContext
  let now = Date(timeIntervalSince1970: 1_800_000_000)
  let subreddit = Subreddit(name: "r/Test")
  context.insert(subreddit)
  context.insert(
    SubredditEvent(
      name: "Past",
      subreddit: subreddit,
      oneOffDate: now.addingTimeInterval(-3600)
    )
  )
  context.insert(
    SubredditEvent(
      name: "Future",
      subreddit: subreddit,
      oneOffDate: now.addingTimeInterval(3600)
    )
  )
  context.insert(
    SubredditEvent(
      name: "Beyond",
      subreddit: subreddit,
      oneOffDate: now.addingTimeInterval(9 * 24 * 3600)
    )
  )
  try context.save()

  let result = try PlannerEventLoader.fetchUpcomingCandidates(context: context, now: now)

  #expect(result.events.map(\.name) == ["Future"])
  #expect(result.hitLimit == false)
}

@Test @MainActor func plannerEventLoaderDoesNotLetPastOneOffsExhaustUpcomingLimit() throws {
  let container = try makeCRUDContainer()
  let context = container.mainContext
  let now = Date(timeIntervalSince1970: 1_800_000_000)
  let subreddit = Subreddit(name: "r/Test")
  context.insert(subreddit)
  for index in 0..<3 {
    context.insert(
      SubredditEvent(
        name: "Past \(index)",
        subreddit: subreddit,
        oneOffDate: now.addingTimeInterval(TimeInterval(-3600 - index))
      )
    )
  }
  context.insert(
    SubredditEvent(
      name: "Future",
      subreddit: subreddit,
      oneOffDate: now.addingTimeInterval(3600)
    )
  )
  try context.save()

  let result = try PlannerEventLoader.fetchUpcomingCandidates(
    context: context,
    now: now,
    limitPerKind: 1
  )

  #expect(result.events.map(\.name) == ["Future"])
  #expect(result.hitLimit)
}

@Test @MainActor func plannerEventLoaderCapsRecurringCandidates() throws {
  let container = try makeCRUDContainer()
  let context = container.mainContext
  let subreddit = Subreddit(name: "r/Test")
  context.insert(subreddit)
  for index in 0..<3 {
    context.insert(
      SubredditEvent(
        name: "Recurring \(index)",
        subreddit: subreddit,
        rrule: "FREQ=DAILY"
      )
    )
  }
  try context.save()

  let result = try PlannerEventLoader.fetchUpcomingCandidates(
    context: context,
    limitPerKind: 2
  )

  #expect(result.recurringCount == 2)
  #expect(result.loadedCount == 2)
  #expect(result.hitLimit)
}
