import Foundation

@MainActor
@Observable
final class TimingEngine {
    struct UpcomingWindow {
        let event: SubredditEvent
        let fireDate: Date
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
            return RRuleHelper.nextOccurrence(rrule: rrule, after: date)
        }
        return nil
    }

    func refresh(events: [SubredditEvent], captures: [Capture]) {
        let now = Date()
        let horizon = now.addingTimeInterval(24 * 3600)

        // Pre-index: build a set of subreddit IDs per queued capture once,
        // then look up by subreddit ID in O(1) instead of O(captures × subreddits).
        var queuedCountBySubredditId: [UUID: Int] = [:]
        for capture in captures where capture.status == .queued {
            for sub in capture.subreddits {
                queuedCountBySubredditId[sub.id, default: 0] += 1
            }
        }

        var windows: [UpcomingWindow] = []

        for event in events where event.isActive {
            guard let fireDate = Self.nextWindow(for: event, after: now),
                  fireDate <= horizon
            else { continue }

            let hours = fireDate.timeIntervalSince(now) / 3600
            let urgency = Self.urgencyLevel(hoursUntilWindow: hours)
            let matchCount = event.subreddit.map { queuedCountBySubredditId[$0.id] ?? 0 } ?? 0

            windows.append(UpcomingWindow(
                event: event,
                fireDate: fireDate,
                urgency: urgency,
                matchingCaptureCount: matchCount
            ))
        }

        upcomingWindows = windows.sorted { $0.fireDate < $1.fireDate }
    }
}
