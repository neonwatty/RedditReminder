import SwiftUI

struct NotificationsTabView: View {
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true
    @AppStorage("nudgeWhenEmpty") private var nudgeWhenEmpty: Bool = true
    @AppStorage("defaultLeadTimeMinutes") private var defaultLeadTimeMinutes: Int = 60

    var body: some View {
        Form {
            Section("Notifications") {
                Toggle("Enable macOS notifications", isOn: $notificationsEnabled)
                    .font(.system(size: 12))

                if notificationsEnabled {
                    Picker("Remind me before events", selection: $defaultLeadTimeMinutes) {
                        Text("15 minutes").tag(15)
                        Text("30 minutes").tag(30)
                        Text("1 hour").tag(60)
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
}
