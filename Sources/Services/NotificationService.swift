import Foundation
import UserNotifications

protocol NotificationCenterProtocol: Sendable {
  func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
  func add(_ request: UNNotificationRequest, withCompletionHandler handler: (@Sendable (Error?) -> Void)?)
  func removePendingNotificationRequests(withIdentifiers identifiers: [String])
  func removeAllPendingNotificationRequests()
  func getAuthorizationStatus() async -> UNAuthorizationStatus
}

extension UNUserNotificationCenter: @retroactive @unchecked Sendable {}
extension UNUserNotificationCenter: NotificationCenterProtocol {
  func getAuthorizationStatus() async -> UNAuthorizationStatus {
    await notificationSettings().authorizationStatus
  }
}

enum AppNotificationIdentifiers {
  static let openAction = "OPEN_ACTION"
  static let markPostedAction = "MARK_POSTED_ACTION"
  static let postingWindowCategory = "POSTING_WINDOW"
  static let emptyQueueNudgeCategory = "EMPTY_QUEUE_NUDGE"
  static let eventIdUserInfoKey = "eventId"
  static let subredditNameUserInfoKey = "subredditName"

  static func windowRequestId(eventId: String) -> String {
    "window-\(eventId)"
  }

  static func nudgeRequestId(eventId: String) -> String {
    "nudge-\(eventId)"
  }
}

@MainActor
final class NotificationService {
  private let center: any NotificationCenterProtocol

  init(center: any NotificationCenterProtocol = UNUserNotificationCenter.current()) {
    self.center = center
  }

  func checkPermissionStatus() async -> UNAuthorizationStatus {
    await center.getAuthorizationStatus()
  }

  func requestPermission() async -> Bool {
    do {
      return try await center.requestAuthorization(options: [.alert, .sound, .badge])
    } catch {
      NSLog("RedditReminder: notification permission error: \(error)")
      return false
    }
  }

  func registerCategories() {
    let categories = Self.categories()
    if let realCenter = center as? UNUserNotificationCenter {
      realCenter.setNotificationCategories(categories)
    }
  }

  static func categories() -> Set<UNNotificationCategory> {
    let openAction = UNNotificationAction(
      identifier: AppNotificationIdentifiers.openAction,
      title: "Open",
      options: [.foreground]
    )
    let markPostedAction = UNNotificationAction(
      identifier: AppNotificationIdentifiers.markPostedAction,
      title: "Mark as Posted",
      options: []
    )

    let windowCategory = UNNotificationCategory(
      identifier: AppNotificationIdentifiers.postingWindowCategory,
      actions: [openAction, markPostedAction],
      intentIdentifiers: []
    )
    let nudgeCategory = UNNotificationCategory(
      identifier: AppNotificationIdentifiers.emptyQueueNudgeCategory,
      actions: [openAction],
      intentIdentifiers: []
    )

    return [windowCategory, nudgeCategory]
  }

  func scheduleWindowNotification(
    eventId: String,
    subredditName: String,
    title: String,
    body: String,
    fireDate: Date
  ) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default
    content.categoryIdentifier = AppNotificationIdentifiers.postingWindowCategory
    content.userInfo = [
      AppNotificationIdentifiers.eventIdUserInfoKey: eventId,
      AppNotificationIdentifiers.subredditNameUserInfoKey: subredditName
    ]

    let comps = Calendar.current.dateComponents(
      [.year, .month, .day, .hour, .minute],
      from: fireDate
    )
    let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

    let request = UNNotificationRequest(
      identifier: AppNotificationIdentifiers.windowRequestId(eventId: eventId),
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
    content.categoryIdentifier = AppNotificationIdentifiers.emptyQueueNudgeCategory
    content.userInfo = [
      AppNotificationIdentifiers.eventIdUserInfoKey: eventId,
      AppNotificationIdentifiers.subredditNameUserInfoKey: subredditName
    ]

    let comps = Calendar.current.dateComponents(
      [.year, .month, .day, .hour, .minute],
      from: fireDate
    )
    let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

    let request = UNNotificationRequest(
      identifier: AppNotificationIdentifiers.nudgeRequestId(eventId: eventId),
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
      withIdentifiers: [
        AppNotificationIdentifiers.windowRequestId(eventId: eventId),
        AppNotificationIdentifiers.nudgeRequestId(eventId: eventId)
      ]
    )
  }

  func cancelAll() {
    center.removeAllPendingNotificationRequests()
  }
}

enum NotificationAuthorizationDisplay {
  static func label(for status: UNAuthorizationStatus) -> String {
    switch status {
    case .authorized:
      return "Allowed"
    case .denied:
      return "Denied"
    case .notDetermined:
      return "Not requested"
    case .provisional:
      return "Provisional"
    case .ephemeral:
      return "Ephemeral"
    @unknown default:
      return "Unknown"
    }
  }
}
