import AppKit
import SwiftUI
import UserNotifications

struct NotificationsTabView: View {
    let notificationService: NotificationService
    var notificationSettingsOpener: NotificationSettingsOpener = .system

    @AppStorage(SettingsKey.notificationsEnabled) private var notificationsEnabled: Bool = true
    @AppStorage(SettingsKey.nudgeWhenEmpty) private var nudgeWhenEmpty: Bool = true
    @AppStorage(SettingsKey.defaultLeadTimeMinutes) private var defaultLeadTimeMinutes: Int = 60
    @State private var authorizationStatus: UNAuthorizationStatus?

    var body: some View {
        Form {
            Section("Notifications") {
                HStack {
                    Text("Permission")
                        .font(.system(size: 12))
                    Spacer()
                    Text(permissionLabel)
                        .font(.system(size: 12))
                        .foregroundStyle(permissionColor)
                }

                HStack(spacing: 12) {
                    Button("Request Permission") {
                        Task { await requestPermission() }
                    }
                    .font(.system(size: 11))

                    Button("Open System Settings") {
                        openNotificationSettings()
                    }
                    .font(.system(size: 11))
                }

                Toggle("Enable macOS notifications", isOn: $notificationsEnabled)
                    .font(.system(size: 12))

                if notificationsEnabled {
                    Picker("Remind me before events", selection: $defaultLeadTimeMinutes) {
                        ForEach(SettingsOptions.leadTimeMinutes, id: \.self) { minutes in
                            Text(Self.leadTimeLabel(minutes)).tag(minutes)
                        }
                    }
                    .font(.system(size: 12))

                    Toggle("Nudge when queue is empty", isOn: $nudgeWhenEmpty)
                        .font(.system(size: 12))
                }
            }
        }
        .formStyle(.grouped)
        .padding(8)
        .task { await refreshPermissionStatus() }
    }

    private static func leadTimeLabel(_ minutes: Int) -> String {
        minutes < 60 ? "\(minutes) minutes" : "\(minutes / 60) hour\(minutes == 60 ? "" : "s")"
    }

    private var permissionLabel: String {
        authorizationStatus.map(NotificationAuthorizationDisplay.label(for:)) ?? "Checking..."
    }

    private var permissionColor: Color {
        switch authorizationStatus {
        case .authorized:
            return .green
        case .denied:
            return .red
        case .notDetermined, .provisional, .ephemeral, nil:
            return .secondary
        @unknown default:
            return .secondary
        }
    }

    private func refreshPermissionStatus() async {
        authorizationStatus = await notificationService.checkPermissionStatus()
    }

    private func requestPermission() async {
        _ = await notificationService.requestPermission()
        await refreshPermissionStatus()
    }

    private func openNotificationSettings() {
        _ = notificationSettingsOpener.openSettings()
    }
}
