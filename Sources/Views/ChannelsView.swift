import SwiftUI
import SwiftData

struct ChannelsView: View {
    let notificationService: NotificationService
    @Query(sort: \Subreddit.sortOrder) private var subreddits: [Subreddit]
    @Environment(\.modelContext) private var modelContext

    @State private var expandedSubredditId: UUID?
    @State private var newSubredditName = ""
    @State private var draggingSubreddit: Subreddit?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                addRow
                redditSection
                discordSection
                socialSection
            }
            .padding(12)
        }
        .onDisappear { savePendingChanges() }
    }

    // MARK: - Add Row

    private var addRow: some View {
        HStack(spacing: 6) {
            TextField("r/NewSubreddit", text: $newSubredditName)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .stickerInput()
                .onSubmit { addSubreddit() }

            Button(action: addSubreddit) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(canAdd ? StickerColors.green : StickerColors.textSecondary)
            }
            .buttonStyle(.plain)
            .disabled(!canAdd)
        }
    }

    private func normalizedSubredditName(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        return trimmed.hasPrefix("r/") ? trimmed : "r/\(trimmed)"
    }

    private var canAdd: Bool {
        guard let name = normalizedSubredditName(newSubredditName) else { return false }
        return !subreddits.contains(where: { $0.name.lowercased() == name.lowercased() })
    }

    private func addSubreddit() {
        guard let name = normalizedSubredditName(newSubredditName) else { return }
        guard !subreddits.contains(where: { $0.name.lowercased() == name.lowercased() }) else { return }

        let nextOrder = (subreddits.map(\.sortOrder).max() ?? -1) + 1
        let sub = Subreddit(name: name, sortOrder: nextOrder)
        modelContext.insert(sub)
        do {
            try modelContext.save()
            newSubredditName = ""
        } catch {
            modelContext.rollback()
            NSLog("RedditReminder: failed to add subreddit: \(error)")
        }
    }

    // MARK: - Reddit Section

    private var redditSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            stickerSectionLabel("Reddit")
            ForEach(subreddits, id: \.id) { sub in
                SubredditRow(
                    sub: sub,
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
    }

    private func toggleExpanded(_ sub: Subreddit) {
        // Save any pending changes from the previously expanded row
        savePendingChanges()

        withAnimation(.easeInOut(duration: 0.2)) {
            if expandedSubredditId == sub.id {
                expandedSubredditId = nil
            } else {
                expandedSubredditId = sub.id
            }
        }
    }

    private func savePendingChanges() {
        if modelContext.hasChanges {
            do {
                try modelContext.save()
            } catch {
                modelContext.rollback()
                NSLog("RedditReminder: failed to save pending channel changes: \(error)")
            }
        }
    }

    // MARK: - Helpers

    private func deleteSubreddit(_ sub: Subreddit) {
        for event in sub.events {
            notificationService.cancelNotifications(eventId: event.id.uuidString)
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            expandedSubredditId = nil
        }
        modelContext.delete(sub)
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            NSLog("RedditReminder: failed to delete subreddit: \(error)")
        }
    }

    // MARK: - Placeholder Sections

    private var discordSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            stickerSectionLabel("Discord")
            placeholderRow(dot: Color(red: 0.35, green: 0.40, blue: 0.95), name: "#show-and-tell")
        }
        .padding(.top, 8)
    }

    private var socialSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            stickerSectionLabel("Social")
            placeholderRow(dot: StickerColors.blue, name: "Twitter/X")
        }
        .padding(.top, 8)
    }

    private func placeholderRow(dot: Color, name: String) -> some View {
        HStack {
            HStack(spacing: 8) {
                Circle().fill(dot).frame(width: 8, height: 8)
                Text(name)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(StickerColors.textPrimary)
            }
            Spacer()
            Text("coming soon")
                .font(.system(size: 9))
                .foregroundStyle(StickerColors.textSecondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(StickerColors.border)
                .clipShape(Capsule())
        }
        .padding(10)
        .stickerCard()
        .opacity(0.4)
    }
}
