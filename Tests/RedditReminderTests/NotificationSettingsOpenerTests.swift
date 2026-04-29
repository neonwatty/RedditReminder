import Foundation
import Testing
@testable import RedditReminder

@Test func notificationSettingsOpenerUsesMacOSNotificationPreferencesURL() {
    #expect(
        NotificationSettingsOpener.notificationSettingsURL.absoluteString ==
        "x-apple.systempreferences:com.apple.preference.notifications"
    )
}

@Test @MainActor func notificationSettingsOpenerDelegatesURLOpening() {
    var openedURLs: [URL] = []
    let opener = NotificationSettingsOpener { url in
        openedURLs.append(url)
        return true
    }

    #expect(opener.openSettings())
    #expect(openedURLs == [NotificationSettingsOpener.notificationSettingsURL])
}
