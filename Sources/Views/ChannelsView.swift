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
        SubredditPersistenceActions.canAdd(newSubredditName, subreddits: subreddits)
    }

    private func addSubreddit() {
        switch SubredditPersistenceActions.addSubreddit(
            named: newSubredditName,
            subreddits: subreddits,
            modelContext: modelContext,
            heuristicsStore: heuristicsStore,
            defaultLeadTimeMinutes: defaultLeadTimeMinutes
        ) {
        case .success:
            newSubredditName = ""
            nameValidationMessage = nil
        case .failure(let error):
            nameValidationMessage = error.message
        }
    }

    private func toggleExpanded(_ sub: Subreddit) {
        savePendingChanges()
        withAnimation(.easeInOut(duration: 0.2)) {
            expandedSubredditId = expandedSubredditId == sub.id ? nil : sub.id
        }
    }

    private func savePendingChanges() {
        SubredditPersistenceActions.savePendingChanges(
            subreddits: subreddits,
            modelContext: modelContext,
            heuristicsStore: heuristicsStore,
            defaultLeadTimeMinutes: defaultLeadTimeMinutes
        )
    }

    private func deleteSubreddit(_ sub: Subreddit) {
        SubredditPersistenceActions.deleteSubreddit(
            sub,
            modelContext: modelContext,
            notificationService: notificationService
        )
    }

    private var defaultLeadTimeMinutes: Int {
        UserDefaults.standard.object(forKey: SettingsKey.defaultLeadTimeMinutes) as? Int ?? 60
    }

}
