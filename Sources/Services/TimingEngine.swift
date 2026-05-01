import Foundation

@MainActor
@Observable
final class TimingEngine {
  struct UpcomingWindow {
    let event: SubredditEvent
    let eventDate: Date
    let notificationFireDate: Date
    let urgency: UrgencyLevel
    let matchingCaptureCount: Int
  }

  private(set) var upcomingWindows: [UpcomingWindow] = []

  static func urgencyLevel(hoursUntilWindow: Double) -> UrgencyLevel {
    switch hoursUntilWindow {
    case _ where hoursUntilWindow < 0:
      return .expired
    case 0..<0.5:
      return .active
    case 0.5..<2:
      return .high
    case 2..<12:
      return .medium
    case 12..<24:
      return .low
    default:
      return .none
    }
  }

  static func nextWindow(for event: SubredditEvent, after date: Date) -> Date? {
    if let oneOff = event.oneOffDate {
      return oneOff > date ? oneOff : nil
    }
    if let rrule = event.rrule {
      if let hour = event.recurrenceHour,
        let minute = event.recurrenceMinute,
        let timeZoneId = event.recurrenceTimeZoneIdentifier,
        let timeZone = TimeZone(identifier: timeZoneId)
      {
        return RRuleHelper.nextOccurrence(
          rrule: rrule,
          after: date,
          hour: hour,
          minute: minute,
          timeZone: timeZone
        )
      }
      return RRuleHelper.nextOccurrence(rrule: rrule, after: date)
    }
    return nil
  }

  func refresh(
    events: [SubredditEvent],
    captures: [Capture],
    now: Date = Date(),
    horizonDays: Int = 7
  ) {
    let horizon = now.addingTimeInterval(TimeInterval(max(1, horizonDays)) * 24 * 3600)

    // Pre-index: count queued captures per subreddit ID once,
    // then look up by subreddit ID in O(1) instead of O(captures × subreddits).
    var queuedCountBySubredditId: [UUID: Int] = [:]
    for capture in captures where capture.status == .queued {
      for sub in capture.subreddits {
        if !capture.postedSubredditIDs.contains(sub.id) {
          queuedCountBySubredditId[sub.id, default: 0] += 1
        }
      }
    }

    var windows: [UpcomingWindow] = []

    for event in events where event.isActive {
      guard let eventDate = Self.nextWindow(for: event, after: now),
        eventDate <= horizon
      else { continue }

      let hours = eventDate.timeIntervalSince(now) / 3600
      let urgency = Self.urgencyLevel(hoursUntilWindow: hours)
      let matchCount = event.subreddit.map { queuedCountBySubredditId[$0.id] ?? 0 } ?? 0

      let leadSeconds = TimeInterval(event.reminderLeadMinutes) * 60
      let notificationFireDate = eventDate.addingTimeInterval(-leadSeconds)

      windows.append(
        UpcomingWindow(
          event: event,
          eventDate: eventDate,
          notificationFireDate: notificationFireDate,
          urgency: urgency,
          matchingCaptureCount: matchCount
        ))
    }

    upcomingWindows = windows.sorted { $0.eventDate < $1.eventDate }
  }
}
