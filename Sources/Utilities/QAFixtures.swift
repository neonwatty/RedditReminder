import Foundation
import SwiftData

enum QAFixtures {
  @MainActor
  static func seed(context: ModelContext) {
    clearAll(context: context)

    // 3 subreddits
    let sideProject = Subreddit(name: "r/SideProject")
    let swiftUI = Subreddit(name: "r/SwiftUI")
    let macOS = Subreddit(name: "r/macOS")
    context.insert(sideProject)
    context.insert(swiftUI)
    context.insert(macOS)

    // 1 project linking 2 subreddits
    let project = Project(name: "BullhornApp", projectDescription: "Social media scheduler")
    context.insert(project)

    // 5 captures: 3 queued, 2 posted
    let c1 = Capture(
      text: "Just shipped v2 with new scheduling engine", project: project,
      subreddits: [sideProject, swiftUI])
    context.insert(c1)

    let c2 = Capture(
      text: "Built a macOS sidebar for Reddit posting reminders", project: project,
      subreddits: [sideProject, macOS])
    context.insert(c2)

    let c3 = Capture(
      text: "SwiftData + NSPanel: lessons from building a floating sidebar", project: project,
      subreddits: [swiftUI])
    context.insert(c3)

    let c4 = Capture(
      text: "How I use sticker bomb design in a native macOS app", project: project,
      subreddits: [macOS])
    c4.markAsPosted()
    context.insert(c4)

    let c5 = Capture(
      text: "XcodeGen + Makefile: reproducible macOS builds", project: project,
      subreddits: [swiftUI, macOS])
    c5.markAsPosted()
    context.insert(c5)

    // 2 events: one upcoming (7 days), one overdue (yesterday)
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
