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

    // Projects
    let project = Project(name: "BullhornApp", projectDescription: "Social media scheduler")
    let project2 = Project(name: "WeekendHacks", projectDescription: "Weekend side projects")
    context.insert(project)
    context.insert(project2)

    // Archived project — exercises ProjectsTabView archive/unarchive flow
    let archivedProj = Project(name: "DeprecatedTool", projectDescription: "No longer maintained")
    archivedProj.archived = true
    context.insert(archivedProj)

    // Captures — markdown text for preview toggle, notes, varied posted timestamps
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

    let c3 = Capture(
      text: "SwiftData + NSPanel: ~~tricky~~ lessons from building a floating sidebar",
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
    c4.postedAt = Date().addingTimeInterval(-3 * 3600)  // 3 hours ago — tests relative time
    context.insert(c4)

    let c5 = Capture(
      text: "XcodeGen + Makefile: reproducible macOS builds",
      links: ["https://github.com/neonwatty/reddit-reminder/blob/main/Makefile"],
      project: project,
      subreddits: [swiftUI, macOS]
    )
    c5.markAsPosted()
    c5.postedAt = Date().addingTimeInterval(-2 * 86400)  // 2 days ago — tests relative time
    context.insert(c5)

    let c6 = Capture(
      text: "Weekend hack: building a [Reddit bot](https://example.com) in Swift",
      notes: "Mention the rate-limiting challenges",
      project: project2,
      subreddits: [iosProg, sideProject]
    )
    context.insert(c6)

    // Posted capture under archived project — exercises PostedListView + archived project
    let c7 = Capture(
      text: "Old tool: **deprecated** CLI for subreddit scraping",
      project: archivedProj,
      subreddits: [iosProg]
    )
    c7.markAsPosted()
    c7.postedAt = Date().addingTimeInterval(-7 * 86400)  // 1 week ago
    context.insert(c7)

    // No-project capture — exercises null project display path
    let c8 = Capture(
      text: "Quick thought: *menu bar apps* are underrated on macOS",
      subreddits: [macOS, sideProject]
    )
    context.insert(c8)

    // Events — mix of urgency levels for dot testing
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

    let farOut = SubredditEvent(
      name: "macOS Weekly",
      subreddit: macOS,
      oneOffDate: Calendar.current.date(byAdding: .day, value: 7, to: Date())  // +7d → none (no dot)
    )
    context.insert(farOut)

    // Seed default project preference
    UserDefaults.standard.set(project.id.uuidString, forKey: SettingsKey.defaultProjectId)

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
      UserDefaults.standard.removeObject(forKey: SettingsKey.defaultProjectId)
      NSLog("RedditReminder: all data cleared")
    } catch {
      NSLog("RedditReminder: failed to clear data: \(error)")
    }
  }
}
