import AppKit
import Foundation
import SwiftData
import Testing
import UserNotifications

@testable import RedditReminder

@Test @MainActor func appDelegateMarksQueuedCapturesForNotificationSubredditAsPosted() throws {
  let fixture = try makeCaptureFixture()
  let delegate = makeNotificationActionDelegate()
  delegate.modelContainer = fixture.container

  delegate.markCapturesAsPosted(forSubreddit: "r/Test")

  #expect(fixture.matching.status == .posted)
  #expect(fixture.matching.postedAt != nil)
  #expect(fixture.alreadyPosted.status == .posted)
  #expect(fixture.unrelated.status == .queued)
}

@Test @MainActor func appDelegateMarkPostedActionIsNoopWithoutContainer() {
  let delegate = makeNotificationActionDelegate()

  delegate.markCapturesAsPosted(forSubreddit: "r/Test")
}

@Test @MainActor func appDelegateMarkPostedActionMarksCapturesAndOpensPopoverHeadlessly() throws {
  let fixture = try makeCaptureFixture()
  let recorder = PopoverActionRecorder()
  let delegate = makeNotificationActionDelegate(popoverOpener: recorder.open)
  delegate.modelContainer = fixture.container

  delegate.handleNotificationAction(
    AppNotificationIdentifiers.markPostedAction, subredditName: "r/Test")

  #expect(fixture.matching.status == .posted)
  #expect(fixture.unrelated.status == .queued)
  #expect(recorder.openCount == 1)
}

@Test @MainActor func appDelegateOpenActionOpensPopoverHeadlessly() {
  let recorder = PopoverActionRecorder()
  let delegate = makeNotificationActionDelegate(popoverOpener: recorder.open)

  delegate.handleNotificationAction(AppNotificationIdentifiers.openAction, subredditName: nil)
  delegate.handleNotificationAction(UNNotificationDefaultActionIdentifier, subredditName: nil)
  delegate.handleNotificationAction("UNKNOWN_ACTION", subredditName: nil)

  #expect(recorder.openCount == 2)
}

#if DEBUG
  @Test @MainActor func appDelegateQACopiesFirstQueuedCaptureText() throws {
    let fixture = try makeCaptureFixture()
    let pasteboard = NotificationActionMockPasteboard()
    let delegate = makeNotificationActionDelegate()
    delegate.modelContainer = fixture.container

    #expect(delegate.qaCopyFirstQueuedCapture(to: pasteboard))
    #expect(pasteboard.storedString == "Other")
  }

  @Test @MainActor func appDelegateQACopiesFirstQueuedSubmitURL() throws {
    let fixture = try makeCaptureFixture()
    let pasteboard = NotificationActionMockPasteboard()
    let delegate = makeNotificationActionDelegate()
    delegate.modelContainer = fixture.container

    #expect(delegate.qaCopyFirstQueuedSubmitURL(to: pasteboard))
    #expect(pasteboard.storedString == "https://www.reddit.com/r/Other/submit")
  }

  @Test @MainActor func appDelegateQAMarksFirstQueuedCapturePosted() throws {
    let fixture = try makeCaptureFixture()
    let delegate = makeNotificationActionDelegate()
    delegate.modelContainer = fixture.container

    #expect(delegate.qaMarkFirstQueuedCapturePosted())
    #expect(fixture.matching.status == .queued)
    #expect(fixture.unrelated.status == .posted)
  }

  @Test @MainActor func appDelegateQACreatesAndDeletesTestCapture() throws {
    let fixture = try makeCaptureFixture()
    let delegate = makeNotificationActionDelegate()
    delegate.modelContainer = fixture.container

    #expect(delegate.qaCreateTestCapture())

    let captures = try fixture.container.mainContext.fetch(FetchDescriptor<Capture>())
    let testCapture = try #require(
      captures.first { $0.title == AppDelegate.qaTestCaptureTitle })
    #expect(testCapture.text == AppDelegate.qaTestCaptureText)
    #expect(testCapture.links == [AppDelegate.qaTestCaptureLink])
    #expect(testCapture.subreddits.first?.name == "r/SideProject")

    #expect(delegate.qaDeleteTestCaptures())

    let remaining = try fixture.container.mainContext.fetch(FetchDescriptor<Capture>())
    #expect(!remaining.contains { $0.title == AppDelegate.qaTestCaptureTitle })
  }

  @Test @MainActor func appDelegateQACopiesFirstQueuedCaptureTitle() throws {
    let fixture = try makeCaptureFixture()
    let pasteboard = NotificationActionMockPasteboard()
    let delegate = makeNotificationActionDelegate()
    delegate.modelContainer = fixture.container
    fixture.unrelated.title = "Newest queued title"
    try fixture.container.mainContext.save()

    #expect(delegate.qaCopyFirstQueuedCaptureTitle(to: pasteboard))
    #expect(pasteboard.storedString == "Newest queued title")
  }
#endif

@MainActor
private func makeNotificationActionDelegate(popoverOpener: (@MainActor () -> Void)? = nil)
  -> AppDelegate
{
  AppDelegate(
    menuBarController: MenuBarController(),
    timingEngine: TimingEngine(),
    notificationService: NotificationService(center: NotificationActionCenter()),
    heuristicsStore: HeuristicsStore(
      bundle: Bundle(path: "/tmp") ?? .main, logsMissingResource: false),
    notificationActionPopoverOpener: popoverOpener
  )
}

@MainActor
private func makeCaptureFixture() throws -> CaptureFixture {
  let container = try ModelContainer(
    for: Project.self, Capture.self, Subreddit.self, SubredditEvent.self,
    configurations: ModelConfiguration(isStoredInMemoryOnly: true)
  )
  let context = container.mainContext
  let target = Subreddit(name: "r/Test")
  let other = Subreddit(name: "r/Other")
  let sideProject = Subreddit(name: "r/SideProject")
  let matching = Capture(text: "Matching", subreddits: [target])
  let alreadyPosted = Capture(text: "Posted", subreddits: [target])
  alreadyPosted.markAsPosted()
  let unrelated = Capture(text: "Other", subreddits: [other])
  context.insert(target)
  context.insert(other)
  context.insert(sideProject)
  context.insert(matching)
  context.insert(alreadyPosted)
  context.insert(unrelated)
  try context.save()
  return CaptureFixture(
    container: container,
    matching: matching,
    alreadyPosted: alreadyPosted,
    unrelated: unrelated
  )
}

private struct CaptureFixture {
  let container: ModelContainer
  let matching: Capture
  let alreadyPosted: Capture
  let unrelated: Capture
}

@MainActor
private final class PopoverActionRecorder {
  private(set) var openCount = 0

  func open() {
    openCount += 1
  }
}

private final class NotificationActionCenter: NotificationCenterProtocol, @unchecked Sendable {
  func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool { true }
  func add(
    _ request: UNNotificationRequest, withCompletionHandler handler: (@Sendable (Error?) -> Void)?
  ) {}
  func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {}
  func removeAllPendingNotificationRequests() {}
  func getAuthorizationStatus() async -> UNAuthorizationStatus { .authorized }
}

#if DEBUG
  private final class NotificationActionMockPasteboard: PasteboardWriting {
    var storedString: String?

    func clearContents() -> Int {
      storedString = nil
      return 1
    }

    func setString(_ string: String, forType dataType: NSPasteboard.PasteboardType) -> Bool {
      storedString = string
      return true
    }
  }
#endif
