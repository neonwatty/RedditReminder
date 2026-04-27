import SwiftUI
import SwiftData

@main
struct RedditReminderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: Project.self, Capture.self, Subreddit.self, SubredditEvent.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup("RedditReminderKeepalive") {
            Color.clear
                .frame(width: 1, height: 1)
                .onAppear {
                    appDelegate.modelContainer = container
                    DefaultSubreddits.seedIfEmpty(context: container.mainContext)
                    appDelegate.runRefreshCycle()
                    let sidebarView = SidebarContainer(
                        panelController: appDelegate.panelController,
                        notificationService: appDelegate.notificationService,
                        onCaptureChanged: { [weak appDelegate] in appDelegate?.runRefreshCycle() }
                    )
                    .modelContainer(container)
                    appDelegate.panelController.setup(contentView: sidebarView)
                }
        }
        .defaultSize(width: 1, height: 1)
        .windowStyle(.hiddenTitleBar)
    }
}
