import SwiftUI
import SwiftData

struct GeneralTabView: View {
    @AppStorage("defaultLeadTimeMinutes") private var defaultLeadTimeMinutes: Int = 60
    @AppStorage("defaultProjectId") private var defaultProjectId: String = ""

    @Query(sort: \Project.name) private var projects: [Project]

    var body: some View {
        Form {
            Section("Keyboard Shortcut") {
                HStack {
                    Text("Toggle popover")
                        .font(.system(size: 12))
                    Spacer()
                    Text("⌘⇧R")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.quaternary.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }

            Section("Defaults") {
                Picker("Default lead time", selection: $defaultLeadTimeMinutes) {
                    Text("30 minutes").tag(30)
                    Text("1 hour").tag(60)
                    Text("2 hours").tag(120)
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
    }
}
