import Foundation
import Testing

@testable import RedditReminder

@Test @MainActor func eventBannerRelativeTimeUsesInjectedReferenceDate() {
  let formatter = RelativeDateTimeFormatter()
  formatter.unitsStyle = .abbreviated
  formatter.locale = Locale(identifier: "en_US_POSIX")

  let referenceDate = Date(timeIntervalSinceReferenceDate: 0)
  let eventDate = referenceDate.addingTimeInterval(2 * 3600)

  #expect(
    EventBannerView.relativeTime(
      eventDate,
      relativeTo: referenceDate,
      formatter: formatter
    ) == "in 2h"
  )
}

@Test @MainActor func eventBannerRelativeTimeHandlesPastDates() {
  let formatter = RelativeDateTimeFormatter()
  formatter.unitsStyle = .abbreviated
  formatter.locale = Locale(identifier: "en_US_POSIX")

  let referenceDate = Date(timeIntervalSinceReferenceDate: 0)
  let eventDate = referenceDate.addingTimeInterval(-30 * 60)

  #expect(
    EventBannerView.relativeTime(
      eventDate,
      relativeTo: referenceDate,
      formatter: formatter
    ) == "30m ago"
  )
}

@Test func eventBannerReadyCaptureTextPluralizesCounts() {
  #expect(EventBannerView.readyCaptureText(count: 0) == nil)
  #expect(EventBannerView.readyCaptureText(count: 1) == "1 capture ready")
  #expect(EventBannerView.readyCaptureText(count: 2) == "2 captures ready")
}

@Test @MainActor func eventBannerAccessibilityLabelSummarizesWindow() {
  let subreddit = Subreddit(name: "r/SwiftUI")
  let event = SubredditEvent(
    name: "Peak posting window",
    subreddit: subreddit,
    oneOffDate: Date(timeIntervalSinceReferenceDate: 3600),
    reminderLeadMinutes: 30
  )
  let window = TimingEngine.UpcomingWindow(
    event: event,
    eventDate: Date(timeIntervalSinceReferenceDate: 3600),
    notificationFireDate: Date(timeIntervalSinceReferenceDate: 1800),
    urgency: .high,
    matchingCaptureCount: 2
  )

  #expect(
    EventBannerView.accessibilityLabel(for: window, additionalWindowCount: 1)
      == "Upcoming posting window, r/SwiftUI — Peak posting window, Posting window soon, 2 captures ready, 1 more window"
  )
}
