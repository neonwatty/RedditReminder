import SwiftUI
import SwiftData

struct ChannelsTabView: View {
    let notificationService: NotificationService

    @Query(sort: \Subreddit.sortOrder) private var subreddits: [Subreddit]
    @Environment(\.modelContext) private var modelContext

    @State private var expandedSubredditId: UUID?
    @State private var newSubredditName = ""
    @State private var draggingSubreddit: Subreddit?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                TextField("Add subreddit...", text: $newSubredditName)
                    .font(.system(size: 11))
                    .textFieldStyle(.plain)
                    .padding(7)
                    .background(.quaternary.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                    )
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
            .padding(12)

            Divider()

            ScrollView {
                VStack(spacing: 8) {
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
                .padding(12)
            }
        }
        .onDisappear { savePendingChanges() }
    }

    private var canAdd: Bool {
        guard let name = normalizedSubredditName() else { return false }
        return !subreddits.contains(where: { $0.name.lowercased() == name.lowercased() })
    }

    private func normalizedSubredditName() -> String? {
        let trimmed = newSubredditName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed.hasPrefix("r/") ? trimmed : "r/\(trimmed)"
    }

    private func addSubreddit() {
        guard let name = normalizedSubredditName(), canAdd else { return }
        let nextOrder = (subreddits.map(\.sortOrder).max() ?? -1) + 1
        let sub = Subreddit(name: name, sortOrder: nextOrder)
        modelContext.insert(sub)
        do { try modelContext.save() }
        catch {
            NSLog("RedditReminder: add subreddit failed: \(error)")
            modelContext.delete(sub)
            return
        }
        newSubredditName = ""
    }

    private func toggleExpanded(_ sub: Subreddit) {
        savePendingChanges()
        withAnimation(.easeInOut(duration: 0.2)) {
            expandedSubredditId = expandedSubredditId == sub.id ? nil : sub.id
        }
    }

    private func savePendingChanges() {
        guard modelContext.hasChanges else { return }
        do { try modelContext.save() }
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
}
