import Foundation

enum PopoverTimingPresentation {
  static func activeEvents(from events: [SubredditEvent]) -> [SubredditEvent] {
    events.filter(\.isActive)
  }

  static func captureTimingSignature(from captures: [Capture]) -> [String] {
    captures.map { capture in
      let subIds = capture.subreddits.map(\.id.uuidString).sorted().joined(separator: ",")
      let postedIds = capture.postedSubredditIDs.map(\.uuidString).sorted().joined(separator: ",")
      return "\(capture.id.uuidString):\(capture.status.rawValue):\(subIds):\(postedIds)"
    }
  }

  static func eventTimingSignature(from events: [SubredditEvent]) -> [String] {
    events.map { event in
      [
        event.id.uuidString,
        event.isActive.description,
        event.rrule ?? "",
        event.oneOffDate?.timeIntervalSince1970.description ?? "",
        event.recurrenceHour?.description ?? "",
        event.recurrenceMinute?.description ?? "",
        event.recurrenceTimeZoneIdentifier ?? "",
        event.reminderLeadMinutes.description,
        event.subreddit?.id.uuidString ?? "",
      ].joined(separator: "|")
    }.sorted()
  }

  static func subredditTimingSignature(from subreddits: [Subreddit]) -> [String] {
    subreddits.map { subreddit in
      [
        subreddit.id.uuidString,
        subreddit.peakDaysOverride?.joined(separator: ",") ?? "",
        subreddit.peakHoursUtcOverride?.map(String.init).joined(separator: ",") ?? "",
      ].joined(separator: "|")
    }
  }

  static func urgencyBySubredditId(from windows: [TimingEngine.UpcomingWindow]) -> [UUID:
    UrgencyLevel]
  {
    var result: [UUID: UrgencyLevel] = [:]
    for window in windows {
      guard let subId = window.event.subreddit?.id else { continue }
      if window.urgency > (result[subId] ?? .none) { result[subId] = window.urgency }
    }
    return result
  }

  static func nextWindowText(
    for capture: Capture,
    windows: [TimingEngine.UpcomingWindow],
    now: Date = Date()
  ) -> String? {
    let subredditIds = Set(capture.subreddits.map(\.id))
    guard
      let window = windows.first(where: { window in
        guard let subredditId = window.event.subreddit?.id else { return false }
        return subredditIds.contains(subredditId)
      })
    else { return nil }

    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return "Next \(formatter.localizedString(for: window.eventDate, relativeTo: now))"
  }

  static func footerText(
    showPosted: Bool,
    queuedCaptureCount: Int,
    postedCaptureCount: Int,
    upcomingEventCount: Int
  ) -> String {
    if showPosted {
      return "\(postedCaptureCount) posted"
    }
    return "\(queuedCaptureCount) capture\(queuedCaptureCount == 1 ? "" : "s") · "
      + "\(upcomingEventCount) event\(upcomingEventCount == 1 ? "" : "s") upcoming"
  }
}
