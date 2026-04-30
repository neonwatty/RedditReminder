import SwiftUI
import SwiftData

struct GeneralTabView: View {
    var onAppStateChanged: AppRefreshAction = {}

    @AppStorage(SettingsKey.defaultLeadTimeMinutes) private var defaultLeadTimeMinutes: Int = 60
    @AppStorage(SettingsKey.defaultProjectId) private var defaultProjectId: String = ""
    @AppStorage(SettingsKey.globalShortcutRegistrationFailed) private var shortcutRegistrationFailed = false
    @State private var shortcutConfig = KeyboardShortcutConfig.load()

    @Query(sort: \Project.name) private var projects: [Project]

    var body: some View {
        Form {
            Section("Keyboard Shortcut") {
                ShortcutRecorderView(config: $shortcutConfig)
                if shortcutRegistrationFailed {
                    Text("Shortcut unavailable. Grant Accessibility permission or choose another shortcut.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Section("Defaults") {
                Picker("Default lead time", selection: $defaultLeadTimeMinutes) {
                    ForEach(SettingsOptions.leadTimeMinutes, id: \.self) { minutes in
                        Text(Self.leadTimeLabel(minutes)).tag(minutes)
                    }
                }
                .font(.system(size: 12))

                Picker("Default project", selection: $defaultProjectId) {
                    Text("None").tag("")
                    ForEach(projects.filter { !$0.archived }, id: \.id) { project in
                        Text(project.name).tag(project.id.uuidString)
                    }
                }
                .font(.system(size: 12))
            }

            Section("Menu Bar") {
                HStack {
                    Text("Icon style")
                        .font(.system(size: 12))
                    Spacer()
                    Text("R circle (default)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding(8)
        .onAppear {
            shortcutConfig = KeyboardShortcutConfig.load()
        }
        .onChange(of: shortcutConfig) { _, newValue in
            KeyboardShortcutConfig.save(newValue)
        }
        .onChange(of: defaultLeadTimeMinutes) {
            onAppStateChanged()
        }
    }

    private static func leadTimeLabel(_ minutes: Int) -> String {
        minutes < 60 ? "\(minutes) minutes" : "\(minutes / 60) hour\(minutes == 60 ? "" : "s")"
    }
}
