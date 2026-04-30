import Foundation
import Testing

@testable import RedditReminder

@Test @MainActor func popoverTimingPresentationFiltersActiveEvents() {
  let subreddit = Subreddit(name: "r/Swift")
  let active = SubredditEvent(
    name: "Active", subreddit: subreddit, oneOffDate: Date().addingTimeInterval(3600))
  let inactive = SubredditEvent(
    name: "Inactive",
    subreddit: subreddit,
    oneOffDate: Date().addingTimeInterval(3600),
    isActive: false
  )

  #expect(
    PopoverTimingPresentation.activeEvents(from: [active, inactive]).map(\.id) == [active.id])
}

@Test @MainActor func popoverTimingPresentationCaptureSignatureTracksStatusAndSortedSubreddits() {
  let swift = Subreddit(name: "r/Swift")
  let mac = Subreddit(name: "r/macOS")
  let capture = Capture(text: "Draft", subreddits: [swift, mac])
  let queuedSignature = PopoverTimingPresentation.captureTimingSignature(from: [capture])[0]

  capture.markAsPosted()
  let postedSignature = PopoverTimingPresentation.captureTimingSignature(from: [capture])[0]

  #expect(queuedSignature.contains(capture.id.uuidString))
  #expect(queuedSignature.contains(CaptureStatus.queued.rawValue))
  #expect(postedSignature.contains(CaptureStatus.posted.rawValue))
  #expect(queuedSignature != postedSignature)
  #expect(
    queuedSignature.contains(
      [swift.id.uuidString, mac.id.uuidString].sorted().joined(separator: ",")))
}

@Test @MainActor func popoverTimingPresentationEventSignatureSortsAndTracksScheduleFields() {
  let subreddit = Subreddit(name: "r/Swift")
  let first = SubredditEvent(
    name: "First",
    subreddit: subreddit,
    rrule: "FREQ=WEEKLY;BYDAY=MO",
    recurrenceHour: 10,
    recurrenceMinute: 30,
    recurrenceTimeZoneIdentifier: "America/Phoenix",
    reminderLeadMinutes: 15
  )
  let second = SubredditEvent(
    name: "Second",
    subreddit: subreddit,
    oneOffDate: Date(timeIntervalSince1970: 100),
    reminderLeadMinutes: 60,
    isActive: false
  )

  let signatures = PopoverTimingPresentation.eventTimingSignature(from: [second, first])

  #expect(signatures == signatures.sorted())
  #expect(
    signatures.contains { $0.contains(first.id.uuidString) && $0.contains("FREQ=WEEKLY;BYDAY=MO") })
  #expect(signatures.contains { $0.contains(second.id.uuidString) && $0.contains("false") })
}

@Test @MainActor func popoverTimingPresentationSubredditSignatureTracksOverrides() {
  let subreddit = Subreddit(
    name: "r/Swift",
    peakDaysOverride: ["mon", "fri"],
    peakHoursUtcOverride: [15, 18]
  )

  let signature = PopoverTimingPresentation.subredditTimingSignature(from: [subreddit])[0]

  #expect(signature.contains(subreddit.id.uuidString))
  #expect(signature.contains("mon,fri"))
  #expect(signature.contains("15,18"))
}

@Test @MainActor func popoverTimingPresentationUsesHighestUrgencyPerSubreddit() {
  let swift = Subreddit(name: "r/Swift")
  let mac = Subreddit(name: "r/macOS")
  let first = SubredditEvent(
    name: "First", subreddit: swift, oneOffDate: Date().addingTimeInterval(3600))
  let second = SubredditEvent(
    name: "Second", subreddit: swift, oneOffDate: Date().addingTimeInterval(7200))
  let third = SubredditEvent(
    name: "Third", subreddit: mac, oneOffDate: Date().addingTimeInterval(7200))
  let windows = [
    window(event: first, urgency: .low),
    window(event: second, urgency: .high),
    window(event: third, urgency: .medium),
  ]

  let urgency = PopoverTimingPresentation.urgencyBySubredditId(from: windows)

  #expect(urgency[swift.id] == .high)
  #expect(urgency[mac.id] == .medium)
}

@Test @MainActor func popoverTimingPresentationShowsNextWindowForCaptureSubreddit() {
  let now = Date(timeIntervalSince1970: 1_700_000_000)
  let swift = Subreddit(name: "r/Swift")
  let mac = Subreddit(name: "r/macOS")
  let capture = Capture(text: "Draft", subreddits: [mac])
  let swiftEvent = SubredditEvent(
    name: "Swift", subreddit: swift, oneOffDate: now.addingTimeInterval(3600))
  let macEvent = SubredditEvent(
    name: "Mac", subreddit: mac, oneOffDate: now.addingTimeInterval(7200))
  let windows = [
    window(event: swiftEvent, eventDate: swiftEvent.oneOffDate!, urgency: .high),
    window(event: macEvent, eventDate: macEvent.oneOffDate!, urgency: .medium),
  ]

  #expect(
    PopoverTimingPresentation.nextWindowText(for: capture, windows: windows, now: now)?
      .hasPrefix("Next ") == true
  )
}

@Test func popoverTimingPresentationFormatsFooterText() {
  #expect(
    PopoverTimingPresentation.footerText(
      showPosted: false,
      queuedCaptureCount: 1,
      postedCaptureCount: 4,
      upcomingEventCount: 1
    ) == "1 capture · 1 event upcoming")
  #expect(
    PopoverTimingPresentation.footerText(
      showPosted: false,
      queuedCaptureCount: 2,
      postedCaptureCount: 4,
      upcomingEventCount: 3
    ) == "2 captures · 3 events upcoming")
  #expect(
    PopoverTimingPresentation.footerText(
      showPosted: true,
      queuedCaptureCount: 2,
      postedCaptureCount: 4,
      upcomingEventCount: 3
    ) == "4 posted")
}

@MainActor
private func window(event: SubredditEvent, urgency: UrgencyLevel) -> TimingEngine.UpcomingWindow {
  let eventDate = Date().addingTimeInterval(3600)
  return window(event: event, eventDate: eventDate, urgency: urgency)
}

@MainActor
private func window(
  event: SubredditEvent,
  eventDate: Date,
  urgency: UrgencyLevel
) -> TimingEngine.UpcomingWindow {
  return TimingEngine.UpcomingWindow(
    event: event,
    eventDate: eventDate,
    notificationFireDate: eventDate,
    urgency: urgency,
    matchingCaptureCount: 0
  )
}
