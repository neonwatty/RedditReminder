import SwiftData
@preconcurrency import UserNotifications

extension AppDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping @Sendable () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let subredditName = userInfo["subredditName"] as? String
        let actionId = response.actionIdentifier

        Task { @MainActor in
            self.handleNotificationAction(actionId, subredditName: subredditName)
            completionHandler()
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping @Sendable (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func handleNotificationAction(_ actionId: String, subredditName: String?) {
        switch actionId {
        case "MARK_POSTED_ACTION":
            if let subredditName {
                markCapturesAsPosted(forSubreddit: subredditName)
            }
            menuBarController.openPopover()
        case UNNotificationDefaultActionIdentifier, "OPEN_ACTION":
            menuBarController.openPopover()
        default:
            break
        }
    }

    func markCapturesAsPosted(forSubreddit name: String) {
        guard let container = modelContainer else {
            NSLog("RedditReminder: markCapturesAsPosted skipped - no ModelContainer")
            return
        }
        let context = container.mainContext
        do {
            let captures = try context.fetch(FetchDescriptor<Capture>())
            let matching = captures.filter { capture in
                capture.status == .queued &&
                capture.subreddits.contains { $0.name == name }
            }
            for capture in matching {
                capture.markAsPosted()
            }
            try context.save()
            NSLog("RedditReminder: marked \(matching.count) captures as posted for \(name)")
        } catch {
            NSLog("RedditReminder: failed to mark captures as posted: \(error)")
        }
    }
}
