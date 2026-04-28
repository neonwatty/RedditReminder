import SwiftUI

struct NotificationsTabView: View {
    @AppStorage(SettingsKey.notificationsEnabled) private var notificationsEnabled: Bool = true
    @AppStorage(SettingsKey.nudgeWhenEmpty) private var nudgeWhenEmpty: Bool = true
    @AppStorage(SettingsKey.defaultLeadTimeMinutes) private var defaultLeadTimeMinutes: Int = 60

    var body: some View {
        Form {
            Section("Notifications") {
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
    }

    private static func leadTimeLabel(_ minutes: Int) -> String {
        minutes < 60 ? "\(minutes) minutes" : "\(minutes / 60) hour\(minutes == 60 ? "" : "s")"
    }
}
