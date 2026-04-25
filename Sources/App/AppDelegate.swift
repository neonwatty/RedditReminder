import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  let panelController = PanelController()
  private let globalShortcut = GlobalShortcut()

  func applicationDidFinishLaunching(_ notification: Notification) {
    globalShortcut.register { [weak self] in
      self?.panelController.toggleCapture()
    }
    NSLog("RedditReminder: launched, ⌘⇧R registered")
  }

  func applicationWillTerminate(_ notification: Notification) {
    globalShortcut.unregister()
  }
}
