import AppKit
import SwiftData
import SwiftUI

@main
struct RedditReminderApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  private let container: ModelContainer?
  private let startupError: Error?

  init() {
    do {
      container = try AppModelContainerFactory.makeContainer()
      startupError = nil
    } catch {
      container = nil
      startupError = error
    }
  }

  var body: some Scene {
    WindowGroup("RedditReminderKeepalive") {
      Color.clear
        .frame(width: 1, height: 1)
        .onAppear {
          if let startupError {
            presentStoreUnavailableAlert(error: startupError)
            return
          }

          guard let container else { return }

          appDelegate.wireMenuActions(container: container)
          #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--seed-qa") {
              QAFixtures.seed(context: container.mainContext)
            } else {
              DefaultSubreddits.seedIfEmpty(context: container.mainContext)
            }
          #else
            DefaultSubreddits.seedIfEmpty(context: container.mainContext)
          #endif
          appDelegate.runRefreshCycle()
          let popoverView = PopoverContentView(
            menuBarController: appDelegate.menuBarController,
            notificationService: appDelegate.notificationService,
            heuristicsStore: appDelegate.heuristicsStore,
            onAppStateChanged: { [weak appDelegate] in appDelegate?.runRefreshCycle() }
          )
          .modelContainer(container)
          appDelegate.menuBarController.setup(popoverContent: popoverView)
          appDelegate.wireMenuActions(container: container)
        }
    }
    .defaultSize(width: 1, height: 1)
    .windowStyle(.hiddenTitleBar)
  }

  private func presentStoreUnavailableAlert(error: Error) {
    let alert = NSAlert()
    alert.alertStyle = .critical
    alert.messageText = "RedditReminder cannot open its data store"
    alert.informativeText = """
      The app did not start with temporary storage because that could make new captures disappear when you quit.

      \(error.localizedDescription)
      """
    alert.addButton(withTitle: "Reveal Data Folder")
    alert.addButton(withTitle: "Quit")
    if alert.runModal() == .alertFirstButtonReturn {
      let directory = AppModelContainerFactory.appSupportDirectory
      try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      NSWorkspace.shared.activateFileViewerSelecting([directory])
    }
    NSApp.terminate(nil)
  }
}
