import AppKit
import SwiftData
import SwiftUI

@main
struct RedditReminderApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  var body: some Scene {
    Settings {
      SettingsSceneView(appDelegate: appDelegate)
    }
  }
}

private struct SettingsSceneView: View {
  let appDelegate: AppDelegate
  @State private var container: ModelContainer?

  var body: some View {
    Group {
      if let container {
        PreferencesView(
          notificationService: appDelegate.notificationService,
          heuristicsStore: appDelegate.heuristicsStore,
          onAppStateChanged: { appDelegate.runRefreshCycle() }
        )
        .modelContainer(container)
      } else {
        VStack(spacing: 8) {
          ProgressView()
          Text("Loading Settings")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .frame(minWidth: 520, idealWidth: 560, minHeight: 360, idealHeight: 420)
    .onAppear {
      container = appDelegate.modelContainer
    }
  }
}
