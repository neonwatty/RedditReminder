import Foundation
import SwiftData

enum QAFixtures {
  @MainActor
  static func seed(context: ModelContext) {
    clearAll(context: context)

    // 4 subreddits — some with peak overrides, some without
    let sideProject = Subreddit(name: "r/SideProject", sortOrder: 0)
    let swiftUI = Subreddit(
      name: "r/SwiftUI",
      sortOrder: 1,
      peakDaysOverride: ["mon", "wed", "fri"],
      peakHoursUtcOverride: [14, 15, 16, 17, 18]
    )
    let macOS = Subreddit(
      name: "r/macOS",
      sortOrder: 2,
      peakDaysOverride: ["tue", "thu"],
      peakHoursUtcOverride: [10, 11, 12, 13, 14]
    )
    let iosProg = Subreddit(name: "r/iOSProgramming", sortOrder: 3)
    context.insert(sideProject)
    context.insert(swiftUI)
    context.insert(macOS)
    context.insert(iosProg)

    // Project
    let project = Project(name: "BullhornApp", projectDescription: "Social media scheduler")
    context.insert(project)

    // Captures with varying link counts
    let c1 = Capture(
      text: "Just shipped v2 with new scheduling engine",
      links: ["https://github.com/neonwatty/bullhorn/releases/v2.0"],
      project: project,
      subreddits: [sideProject, swiftUI]
    )
    context.insert(c1)

    let c2 = Capture(
      text: "Built a macOS sidebar for Reddit posting reminders",
      links: [
        "https://github.com/neonwatty/reddit-reminder",
        "https://reddit-reminder.app"
      ],
      project: project,
      subreddits: [sideProject, macOS]
    )
    context.insert(c2)

    let c3 = Capture(
      text: "SwiftData + NSPanel: lessons from building a floating sidebar",
      project: project,
      subreddits: [swiftUI]
    )
    context.insert(c3)

    let c4 = Capture(
      text: "How I use sticker bomb design in a native macOS app",
      project: project,
      subreddits: [macOS]
    )
    c4.markAsPosted()
    context.insert(c4)

    let c5 = Capture(
      text: "XcodeGen + Makefile: reproducible macOS builds",
      links: ["https://github.com/neonwatty/reddit-reminder/blob/main/Makefile"],
      project: project,
      subreddits: [swiftUI, macOS]
    )
    c5.markAsPosted()
    context.insert(c5)

    // Events
    let upcoming = SubredditEvent(
      name: "Weekly SideProject",
      subreddit: sideProject,
      oneOffDate: Calendar.current.date(byAdding: .day, value: 7, to: Date())
    )
    context.insert(upcoming)

    let overdue = SubredditEvent(
      name: "SwiftUI Show & Tell",
      subreddit: swiftUI,
      oneOffDate: Calendar.current.date(byAdding: .day, value: -1, to: Date())
    )
    context.insert(overdue)

    do {
      try context.save()
      NSLog("RedditReminder: QA fixtures seeded")
    } catch {
      NSLog("RedditReminder: QA seed SAVE FAILED: \(error)")
    }
  }

  @MainActor
  static func clearAll(context: ModelContext) {
    do {
      try context.delete(model: Capture.self)
      try context.delete(model: SubredditEvent.self)
      try context.delete(model: Project.self)
      try context.delete(model: Subreddit.self)
      try context.save()
      NSLog("RedditReminder: all data cleared")
    } catch {
      NSLog("RedditReminder: failed to clear data: \(error)")
    }
  }
}
