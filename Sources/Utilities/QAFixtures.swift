import Foundation
import SwiftData

enum QAFixtures {
  static let seedLaunchArgument = "--seed-qa"
  static let clearLaunchArgument = "--clear-qa"

  @MainActor
  static func seed(
    context: ModelContext,
    defaults: UserDefaults = .standard,
    mediaStore: MediaStore? = nil
  ) {
    clearAll(context: context, defaults: defaults, mediaStore: mediaStore)

    // Channels cover plain, overridden, checklist, and generated-window states.
    let sideProject = Subreddit(
      name: "r/SideProject",
      sortOrder: 0,
      postingChecklist: "Lead with the product outcome. Include a concise build note and ask one question."
    )
    let swiftUI = Subreddit(
      name: "r/SwiftUI",
      sortOrder: 1,
      peakDaysOverride: ["mon", "wed", "fri"],
      peakHoursUtcOverride: [14, 15, 16, 17, 18],
      postingChecklist: "Mention the SwiftUI pattern, macOS version, and one implementation tradeoff."
    )
    let macOS = Subreddit(
      name: "r/macOS",
      sortOrder: 2,
      peakDaysOverride: ["tue", "thu"],
      peakHoursUtcOverride: [10, 11, 12, 13, 14],
      postingChecklist: "Use a screenshot or short clip when possible. Avoid release-note-only copy."
    )
    let indieHackers = Subreddit(
      name: "r/IndieHackers",
      sortOrder: 3,
      peakDaysOverride: ["sat", "sun"],
      peakHoursUtcOverride: [16, 17, 18, 19],
      postingChecklist: "Include metrics, pricing context, or a concrete lesson learned."
    )
    let noCaptureQA = Subreddit(
      name: "r/NoCaptureQA",
      sortOrder: 4,
      postingChecklist: "QA-only channel with an upcoming planner window and no queued captures."
    )
    context.insert(sideProject)
    context.insert(swiftUI)
    context.insert(macOS)
    context.insert(indieHackers)
    context.insert(noCaptureQA)

    // Projects cover active, launch, and archived management flows.
    let bullhorn = Project(
      name: "BullhornApp",
      projectDescription: "Social media scheduler",
      color: "orange"
    )
    context.insert(bullhorn)

    let redditReminder = Project(
      name: "RedditReminder",
      projectDescription: "Menu bar posting workflow",
      color: "blue"
    )
    context.insert(redditReminder)

    // Archived project exercises ProjectsTabView archive/unarchive flow.
    let archivedProj = Project(
      name: "DeprecatedTool",
      projectDescription: "No longer maintained",
      color: "gray"
    )
    archivedProj.archived = true
    context.insert(archivedProj)

    // Captures cover queue cards, links, media, notes, title-only, multi-channel, and partial-post states.
    let c1 = Capture(
      title: "Launch thread for Bullhorn v2",
      text: "Just shipped **v2** with new *scheduling engine* — totally rebuilt",
      links: ["https://github.com/neonwatty/bullhorn/releases/v2.0"],
      project: bullhorn,
      subreddits: [sideProject, swiftUI, indieHackers]
    )
    c1.createdAt = Date().addingTimeInterval(-7 * 3600)
    context.insert(c1)

    let c2 = Capture(
      title: "Menu bar workflow screenshot",
      text: "Built a macOS sidebar for Reddit posting reminders",
      notes: "Include screenshots of the sidebar in dark mode",
      links: [
        "https://github.com/neonwatty/reddit-reminder",
        "https://reddit-reminder.app"
      ],
      project: redditReminder,
      subreddits: [sideProject, macOS]
    )
    c2.createdAt = Date().addingTimeInterval(-6 * 3600)
    attachFixtureMedia(to: c2, mediaStore: mediaStore)
    context.insert(c2)

    let c3 = Capture(
      title: "Title-only launch reminder",
      text: "",
      notes: "Use this to verify title-only capture display and save/handoff behavior.",
      project: redditReminder,
      subreddits: [sideProject]
    )
    c3.createdAt = Date().addingTimeInterval(-5 * 3600)
    context.insert(c3)

    let c4 = Capture(
      title: "Partially posted multi-channel update",
      text: "Testing per-subreddit progress for a cross-posted launch note.",
      project: bullhorn,
      subreddits: [sideProject, swiftUI, macOS]
    )
    c4.createdAt = Date().addingTimeInterval(-4 * 3600)
    c4.markSubredditAsPosted(sideProject.id)
    context.insert(c4)

    let c5 = Capture(
      title: "Long copy stress test",
      text: String(
        repeating: "This longer queued capture exercises card wrapping, notes, and compact metadata density. ",
        count: 8
      ),
      notes: "Check whether card actions stay visible and readable with long body copy.",
      links: ["https://example.com/long-copy"],
      project: redditReminder,
      subreddits: [indieHackers]
    )
    c5.createdAt = Date().addingTimeInterval(-3 * 3600)
    context.insert(c5)

    // Posted capture under archived project exercises PostedListView plus archived project context.
    let c6 = Capture(
      title: "Archived project retrospective",
      text: "Old tool: **deprecated** CLI for subreddit scraping",
      project: archivedProj,
      subreddits: [swiftUI]
    )
    c6.markAsPosted(postedURL: "https://www.reddit.com/r/SwiftUI/comments/qa001/archive_retrospective/")
    c6.postedAt = Date().addingTimeInterval(-7 * 86400)
    c6.createdAt = Date().addingTimeInterval(-8 * 86400)
    context.insert(c6)

    let c7 = Capture(
      title: "Posted launch recap",
      text: "Short recap with a saved Reddit URL.",
      project: redditReminder,
      subreddits: [sideProject]
    )
    c7.markAsPosted(postedURL: "https://www.reddit.com/r/SideProject/comments/qa002/reddit_reminder_recap/")
    c7.postedAt = Date().addingTimeInterval(-2 * 86400)
    c7.createdAt = Date().addingTimeInterval(-3 * 86400)
    context.insert(c7)

    // Keep this as the newest queued capture because scripts/qa.sh asserts it as the first queued item.
    let c8 = Capture(
      text: "Quick thought: *menu bar apps* are underrated on macOS",
      subreddits: [macOS, sideProject]
    )
    c8.createdAt = Date().addingTimeInterval(-30 * 60)
    context.insert(c8)

    // Events mix urgent/manual, recurring/manual, generated/auto, inactive, and different time zones.
    let imminent = SubredditEvent(
      name: "SideProject Saturday",
      subreddit: sideProject,
      oneOffDate: Date().addingTimeInterval(1 * 3600),
      reminderLeadMinutes: 30
    )
    context.insert(imminent)

    let soonish = SubredditEvent(
      name: "SwiftUI Show & Tell",
      subreddit: swiftUI,
      oneOffDate: Date().addingTimeInterval(6 * 3600),
      reminderLeadMinutes: 60
    )
    context.insert(soonish)

    let recurringManual = SubredditEvent(
      name: "macOS Weekly Apps",
      subreddit: macOS,
      rrule: "FREQ=WEEKLY;BYDAY=TH",
      recurrenceHour: 16,
      recurrenceMinute: 30,
      recurrenceTimeZoneIdentifier: "America/Los_Angeles",
      reminderLeadMinutes: 120
    )
    context.insert(recurringManual)

    let generatedWindow = SubredditEvent(
      name: "Auto peak window: IndieHackers",
      subreddit: indieHackers,
      rrule: "FREQ=WEEKLY;BYDAY=SA",
      recurrenceHour: 17,
      recurrenceMinute: 0,
      recurrenceTimeZoneIdentifier: "UTC",
      reminderLeadMinutes: 45,
      isGeneratedFromHeuristics: true,
      generationKey: "qa-indiehackers-sat-17"
    )
    context.insert(generatedWindow)

    let noCapturePlannerWindow = SubredditEvent(
      name: "No Capture QA Window",
      subreddit: noCaptureQA,
      oneOffDate: Date().addingTimeInterval(2 * 3600),
      reminderLeadMinutes: 30
    )
    context.insert(noCapturePlannerWindow)

    let inactiveEvent = SubredditEvent(
      name: "Paused launch window",
      subreddit: sideProject,
      oneOffDate: Date().addingTimeInterval(48 * 3600),
      isActive: false
    )
    context.insert(inactiveEvent)

    // Seed default project preference
    defaults.set(redditReminder.id.uuidString, forKey: SettingsKey.defaultProjectId)

    do {
      try context.save()
      NSLog("RedditReminder: QA fixtures seeded")
    } catch {
      NSLog("RedditReminder: QA seed SAVE FAILED: \(error)")
    }
  }

  @MainActor
  static func clearAll(
    context: ModelContext,
    defaults: UserDefaults = .standard,
    mediaStore: MediaStore? = nil
  ) {
    do {
      for capture in try context.fetch(FetchDescriptor<Capture>()) {
        mediaStore?.deleteAll(captureId: capture.id)
        context.delete(capture)
      }
      for event in try context.fetch(FetchDescriptor<SubredditEvent>()) {
        context.delete(event)
      }
      for project in try context.fetch(FetchDescriptor<Project>()) {
        context.delete(project)
      }
      for subreddit in try context.fetch(FetchDescriptor<Subreddit>()) {
        context.delete(subreddit)
      }
      try context.save()
      defaults.removeObject(forKey: SettingsKey.defaultProjectId)
      NSLog("RedditReminder: all data cleared")
    } catch {
      NSLog("RedditReminder: failed to clear data: \(error)")
    }
  }

}
