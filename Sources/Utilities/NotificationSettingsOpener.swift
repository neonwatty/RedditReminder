import AppKit
import Foundation

struct NotificationSettingsOpener: Sendable {
    var openURL: @MainActor @Sendable (URL) -> Bool

    static let notificationSettingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.notifications")!

    @MainActor
    static let system = NotificationSettingsOpener { url in
        NSWorkspace.shared.open(url)
    }

    @MainActor
    func openSettings() -> Bool {
        openURL(Self.notificationSettingsURL)
    }
}
