import SwiftUI

struct SettingsView: View {
    @Bindable var panelController: PanelController

    @AppStorage("screenEdge") private var screenEdge = "right"
    @AppStorage("restingState") private var restingState = "glance"
    @AppStorage("autoCollapseMinutes") private var autoCollapseMinutes = 5
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("defaultLeadTimeMinutes") private var defaultLeadTimeMinutes = 60
    @AppStorage("nudgeWhenEmpty") private var nudgeWhenEmpty = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                stickerSectionLabel("Sidebar Behavior", size: 10)

                LabeledContent("Screen edge") {
                    Picker("", selection: $screenEdge) {
                        Text("Left").tag("left")
                        Text("Right").tag("right")
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 150)
                    .onChange(of: screenEdge) { _, newVal in
                        panelController.setScreenEdge(newVal == "left" ? .left : .right)
                    }
                }

                LabeledContent("Resting state") {
                    Picker("", selection: $restingState) {
                        Text("Strip").tag("strip")
                        Text("Glance").tag("glance")
                        Text("Browse").tag("browse")
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 200)
                }

                LabeledContent("Auto-collapse") {
                    Picker("", selection: $autoCollapseMinutes) {
                        Text("1 min").tag(1)
                        Text("5 min").tag(5)
                        Text("15 min").tag(15)
                        Text("30 min").tag(30)
                        Text("Never").tag(0)
                    }
                    .frame(maxWidth: 120)
                }

                StickerDivider()
                stickerSectionLabel("Notifications", size: 10)

                Toggle("macOS notifications", isOn: $notificationsEnabled)

                LabeledContent("Default lead time") {
                    Picker("", selection: $defaultLeadTimeMinutes) {
                        Text("30 min").tag(30)
                        Text("1 hour").tag(60)
                        Text("2 hours").tag(120)
                    }
                    .frame(maxWidth: 120)
                }

                Toggle("Nudge when queue empty", isOn: $nudgeWhenEmpty)
            }
            .padding(16)
        }
    }

}
