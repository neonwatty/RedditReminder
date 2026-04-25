import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let panelController = PanelController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("RedditReminder: launched")
    }
}
