import Foundation
import UserNotifications

protocol NotificationCenterProtocol: Sendable {
  func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
  func add(_ request: UNNotificationRequest, withCompletionHandler handler: (@Sendable (Error?) -> Void)?)
  func removePendingNotificationRequests(withIdentifiers identifiers: [String])
  func removeAllPendingNotificationRequests()
}

extension UNUserNotificationCenter: @retroactive @unchecked Sendable {}
extension UNUserNotificationCenter: NotificationCenterProtocol {}

@MainActor
final class NotificationService {
  private let center: any NotificationCenterProtocol

  init(center: any NotificationCenterProtocol = UNUserNotificationCenter.current()) {
    self.center = center
  }

  func requestPermission() async -> Bool {
    do {
      return try await center.requestAuthorization(options: [.alert, .sound, .badge])
    } catch {
      NSLog("RedditReminder: notification permission error: \(error)")
      return false
    }
  }

  func scheduleWindowNotification(
    eventId: String,
    title: String,
    body: String,
    fireDate: Date
  ) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default
    content.categoryIdentifier = "POSTING_WINDOW"

    let comps = Calendar.current.dateComponents(
      [.year, .month, .day, .hour, .minute],
      from: fireDate
    )
    let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

    let request = UNNotificationRequest(
      identifier: "window-\(eventId)",
      content: content,
      trigger: trigger
    )

    center.add(request) { error in
      if let error {
        NSLog("RedditReminder: failed to schedule notification: \(error)")
      }
    }
  }

  func scheduleEmptyQueueNudge(
    eventId: String,
    subredditName: String,
    eventName: String,
    fireDate: Date
  ) {
    let content = UNMutableNotificationContent()
    content.title = "\(eventName) is approaching"
    content.body = "Nothing queued for \(subredditName) yet — capture something?"
    content.sound = .default
    content.categoryIdentifier = "EMPTY_QUEUE_NUDGE"

    let comps = Calendar.current.dateComponents(
      [.year, .month, .day, .hour, .minute],
      from: fireDate
    )
    let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

    let request = UNNotificationRequest(
      identifier: "nudge-\(eventId)",
      content: content,
      trigger: trigger
    )

    center.add(request) { error in
      if let error {
        NSLog("RedditReminder: failed to schedule nudge: \(error)")
      }
    }
  }

  func cancelNotifications(eventId: String) {
    center.removePendingNotificationRequests(
      withIdentifiers: ["window-\(eventId)", "nudge-\(eventId)"]
    )
  }

  func cancelAll() {
    center.removeAllPendingNotificationRequests()
  }
}
