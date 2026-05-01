import Foundation
import SwiftData

enum QAFixtures {
  @MainActor
  static func seed(context: ModelContext, defaults: UserDefaults = .standard) {
    clearAll(context: context, defaults: defaults)

    // Subreddits — some with peak overrides, some without.
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
    context.insert(sideProject)
    context.insert(swiftUI)
    context.insert(macOS)

    // Projects
    let project = Project(name: "BullhornApp", projectDescription: "Social media scheduler")
    context.insert(project)

    // Archived project — exercises ProjectsTabView archive/unarchive flow
    let archivedProj = Project(name: "DeprecatedTool", projectDescription: "No longer maintained")
    archivedProj.archived = true
    context.insert(archivedProj)

    // Captures — compact enough for manual QA, varied enough for smoke coverage.
    let c1 = Capture(
      text: "Just shipped **v2** with new *scheduling engine* — totally rebuilt",
      links: ["https://github.com/neonwatty/bullhorn/releases/v2.0"],
      project: project,
      subreddits: [sideProject, swiftUI]
    )
    context.insert(c1)

    let c2 = Capture(
      text: "Built a macOS sidebar for Reddit posting reminders",
      notes: "Include screenshots of the sidebar in dark mode",
      links: [
        "https://github.com/neonwatty/reddit-reminder",
        "https://reddit-reminder.app"
      ],
      project: project,
      subreddits: [sideProject, macOS]
    )
    context.insert(c2)

    // Posted capture under archived project — exercises PostedListView + archived project
    let c3 = Capture(
      text: "Old tool: **deprecated** CLI for subreddit scraping",
      project: archivedProj,
      subreddits: [swiftUI]
    )
    c3.markAsPosted()
    c3.postedAt = Date().addingTimeInterval(-7 * 86400)  // 1 week ago
    context.insert(c3)

    // No-project capture — exercises null project display path
    let c4 = Capture(
      text: "Quick thought: *menu bar apps* are underrated on macOS",
      subreddits: [macOS, sideProject]
    )
    context.insert(c4)

    // Events — mix of urgency levels for dot testing.
    let imminent = SubredditEvent(
      name: "SideProject Saturday",
      subreddit: sideProject,
      oneOffDate: Date().addingTimeInterval(1 * 3600)  // +1hr → high (orange dot)
    )
    context.insert(imminent)

    let soonish = SubredditEvent(
      name: "SwiftUI Show & Tell",
      subreddit: swiftUI,
      oneOffDate: Date().addingTimeInterval(6 * 3600)  // +6hr → medium (green dot)
    )
    context.insert(soonish)

    // Seed default project preference
    defaults.set(project.id.uuidString, forKey: SettingsKey.defaultProjectId)

    do {
      try context.save()
      NSLog("RedditReminder: QA fixtures seeded")
    } catch {
      NSLog("RedditReminder: QA seed SAVE FAILED: \(error)")
    }
  }

  @MainActor
  static func clearAll(context: ModelContext, defaults: UserDefaults = .standard) {
    do {
      try context.delete(model: Capture.self)
      try context.delete(model: SubredditEvent.self)
      try context.delete(model: Project.self)
      try context.delete(model: Subreddit.self)
      try context.save()
      defaults.removeObject(forKey: SettingsKey.defaultProjectId)
      NSLog("RedditReminder: all data cleared")
    } catch {
      NSLog("RedditReminder: failed to clear data: \(error)")
    }
  }
}
