import SwiftUI
import SwiftData

struct ChannelsTabView: View {
    let notificationService: NotificationService
    let heuristicsStore: HeuristicsStore

    @Query(sort: \Subreddit.sortOrder) private var subreddits: [Subreddit]
    @Environment(\.modelContext) private var modelContext

    @State private var expandedSubredditId: UUID?
    @State private var newSubredditName = ""
    @State private var nameValidationMessage: String?
    @State private var draggingSubreddit: Subreddit?

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    TextField("Add subreddit...", text: $newSubredditName)
                        .font(.system(size: 11))
                        .textFieldStyle(.plain)
                        .padding(7)
                        .inputFieldStyle(cornerRadius: 6)
                        .onChange(of: newSubredditName) {
                            nameValidationMessage = nil
                        }
                        .onSubmit { addSubreddit() }

                    Button(action: addSubreddit) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .light))
                            .foregroundStyle(canAdd ? AppColors.redditOrange : .secondary)
                            .frame(width: 26, height: 26)
                            .background(
                                canAdd
                                    ? AppColors.redditOrange.opacity(0.15)
                                    : Color.clear
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canAdd)
                }

                if let nameValidationMessage {
                    Text(nameValidationMessage)
                        .font(.system(size: 10))
                        .foregroundStyle(.red)
                }
            }
            .padding(12)

            Divider()

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(subreddits, id: \.id) { sub in
                        SubredditRow(
                            sub: sub,
                            peakInfo: heuristicsStore.peakInfo(for: sub),
                            isExpanded: expandedSubredditId == sub.id,
                            onToggle: { toggleExpanded(sub) },
                            onDelete: { deleteSubreddit(sub) }
                        )
                        .onDrag {
                            draggingSubreddit = sub
                            return NSItemProvider(object: sub.id.uuidString as NSString)
                        }
                        .onDrop(of: [.text], delegate: SubredditDropDelegate(
                            target: sub,
                            dragging: $draggingSubreddit,
                            subreddits: subreddits,
                            modelContext: modelContext
                        ))
                    }
                }
                .padding(12)
            }
        }
        .onDisappear { savePendingChanges() }
    }

    private var canAdd: Bool {
        guard let name = SubredditName.normalizedName(newSubredditName) else { return false }
        return isNameAvailable(name)
    }

    private func isNameAvailable(_ name: String) -> Bool {
        !subreddits.contains(where: { $0.name.lowercased() == name.lowercased() })
    }

    private func addSubreddit() {
        let normalized = SubredditName.normalize(newSubredditName)
        guard case .success(let name) = normalized else {
            if case .failure(let error) = normalized {
                nameValidationMessage = error.message
            }
            return
        }
        guard isNameAvailable(name) else {
            nameValidationMessage = "That subreddit is already in your list."
            return
        }
        let nextOrder = (subreddits.map(\.sortOrder).max() ?? -1) + 1
        let sub = Subreddit(name: name, sortOrder: nextOrder)
        modelContext.insert(sub)
        do {
            try modelContext.save()
            try syncGeneratedEvents(for: sub)
        }
        catch {
            NSLog("RedditReminder: add subreddit failed: \(error)")
            modelContext.delete(sub)
            return
        }
        newSubredditName = ""
        nameValidationMessage = nil
    }

    private func toggleExpanded(_ sub: Subreddit) {
        savePendingChanges()
        withAnimation(.easeInOut(duration: 0.2)) {
            expandedSubredditId = expandedSubredditId == sub.id ? nil : sub.id
        }
    }

    private func savePendingChanges() {
        guard modelContext.hasChanges else { return }
        do {
            try modelContext.save()
            try heuristicsStore.syncGeneratedEvents(
                for: subreddits,
                context: modelContext,
                defaultLeadTimeMinutes: defaultLeadTimeMinutes
            )
        }
        catch { NSLog("RedditReminder: save pending changes failed: \(error)") }
    }

    private func deleteSubreddit(_ sub: Subreddit) {
        for event in sub.events {
            notificationService.cancelNotifications(eventId: event.id.uuidString)
        }
        modelContext.delete(sub)
        do { try modelContext.save() }
        catch {
            NSLog("RedditReminder: delete subreddit failed: \(error)")
            modelContext.rollback()
        }
    }

    private var defaultLeadTimeMinutes: Int {
        UserDefaults.standard.object(forKey: SettingsKey.defaultLeadTimeMinutes) as? Int ?? 60
    }

    private func syncGeneratedEvents(for sub: Subreddit) throws {
        try heuristicsStore.syncGeneratedEvents(
            for: sub,
            context: modelContext,
            defaultLeadTimeMinutes: defaultLeadTimeMinutes
        )
    }
}
