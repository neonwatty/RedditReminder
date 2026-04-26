import SwiftUI
import SwiftData
import UserNotifications

struct SettingsView: View {
    @Bindable var panelController: PanelController

    @Query(sort: \Subreddit.name) private var subreddits: [Subreddit]
    @Environment(\.modelContext) private var modelContext

    @AppStorage("screenEdge") private var screenEdge = "right"
    @AppStorage("restingState") private var restingState = "glance"
    @AppStorage("autoCollapseMinutes") private var autoCollapseMinutes = 5
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("defaultLeadTimeMinutes") private var defaultLeadTimeMinutes = 60
    @AppStorage("nudgeWhenEmpty") private var nudgeWhenEmpty = true

    @State private var newSubredditName = ""

    private func syncAutoCollapse() {
        guard let state = SidebarState(rawValue: restingState) else {
            NSLog("RedditReminder: invalid restingState rawValue: \(restingState)")
            return
        }
        panelController.setAutoCollapse(minutes: autoCollapseMinutes, restingState: state)
    }

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
                    .onChange(of: restingState) { syncAutoCollapse() }
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
                    .onChange(of: autoCollapseMinutes) { syncAutoCollapse() }
                }

                StickerDivider()
                stickerSectionLabel("Notifications", size: 10)

                Toggle("macOS notifications", isOn: $notificationsEnabled)
                    .onChange(of: notificationsEnabled) { _, enabled in
                        if !enabled {
                            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                        }
                    }

                LabeledContent("Default lead time") {
                    Picker("", selection: $defaultLeadTimeMinutes) {
                        Text("30 min").tag(30)
                        Text("1 hour").tag(60)
                        Text("2 hours").tag(120)
                    }
                    .frame(maxWidth: 120)
                }

                Toggle("Nudge when queue empty", isOn: $nudgeWhenEmpty)

                StickerDivider()
                stickerSectionLabel("Subreddits", size: 10)

                subredditAddRow

                ForEach(subreddits, id: \.id) { sub in
                    HStack {
                        Text(sub.name)
                            .font(.system(size: 12))
                            .foregroundStyle(StickerColors.textPrimary)
                        Spacer()
                        Button(action: { deleteSubreddit(sub) }) {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                                .foregroundStyle(StickerColors.reddit)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding(16)
        }
    }

    private var subredditAddRow: some View {
        HStack(spacing: 6) {
            TextField("r/NewSubreddit", text: $newSubredditName)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .stickerInput()
                .onSubmit { addSubreddit() }

            Button(action: addSubreddit) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(canAddSubreddit ? StickerColors.green : StickerColors.textSecondary)
            }
            .buttonStyle(.plain)
            .disabled(!canAddSubreddit)
        }
    }

    private var canAddSubreddit: Bool {
        let trimmed = newSubredditName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        let normalized = trimmed.hasPrefix("r/") ? trimmed : "r/\(trimmed)"
        return !subreddits.contains { $0.name.lowercased() == normalized.lowercased() }
    }

    private func addSubreddit() {
        let trimmed = newSubredditName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let name = trimmed.hasPrefix("r/") ? trimmed : "r/\(trimmed)"

        guard !subreddits.contains(where: { $0.name.lowercased() == name.lowercased() }) else { return }

        let sub = Subreddit(name: name)
        modelContext.insert(sub)
        do {
            try modelContext.save()
            newSubredditName = ""
        } catch {
            modelContext.rollback()
            NSLog("RedditReminder: failed to add subreddit: \(error)")
        }
    }

    private func deleteSubreddit(_ sub: Subreddit) {
        modelContext.delete(sub)
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            NSLog("RedditReminder: failed to delete subreddit: \(error)")
        }
    }

}
