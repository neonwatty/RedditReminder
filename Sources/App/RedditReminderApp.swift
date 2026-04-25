import SwiftUI
import SwiftData

@main
struct RedditReminderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup("RedditReminderKeepalive") {
            Color.clear
                .frame(width: 1, height: 1)
                .onAppear {
                    let container = SidebarContainer(panelController: appDelegate.panelController)
                    appDelegate.panelController.setup(contentView: container)
                }
        }
        .defaultSize(width: 1, height: 1)
        .windowStyle(.hiddenTitleBar)
    }
}
