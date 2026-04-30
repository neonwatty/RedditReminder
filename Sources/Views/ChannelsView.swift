import SwiftData
import SwiftUI

struct ChannelsTabView: View {
  let notificationService: NotificationService
  let heuristicsStore: HeuristicsStore

  @Query(sort: \Subreddit.sortOrder) private var subreddits: [Subreddit]
  @Environment(\.modelContext) private var modelContext

  @State private var expandedSubredditId: UUID?
  @State private var newSubredditName = ""
  @State private var addFailureMessage: String?
  @State private var draggingSubreddit: Subreddit?
  @AppStorage(SettingsKey.defaultLeadTimeMinutes) private var defaultLeadTimeMinutes: Int = 60

  var body: some View {
    VStack(spacing: 0) {
      VStack(alignment: .leading, spacing: 5) {
        HStack(spacing: 8) {
          TextField("Add subreddit...", text: $newSubredditName)
            .font(.system(size: 11))
            .textFieldStyle(.plain)
            .padding(7)
            .inputFieldStyle(cornerRadius: 6)
            .accessibilityLabel("Add subreddit")
            .accessibilityIdentifier("channels.addSubreddit.textField")
            .onChange(of: newSubredditName) {
              addFailureMessage = nil
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
          .accessibilityLabel("Add subreddit")
          .accessibilityIdentifier("channels.addSubreddit.button")
        }

        if let feedbackMessage {
          Text(feedbackMessage.text)
            .font(.system(size: 10))
            .foregroundStyle(feedbackMessage.isError ? .red : .secondary)
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
            .onDrop(
              of: [.text],
              delegate: SubredditDropDelegate(
                target: sub,
                dragging: $draggingSubreddit,
                subreddits: subreddits,
                modelContext: modelContext
              ))
          }
        }
        .padding(12)
      }
      .accessibilityLabel("Subreddit list")
      .accessibilityIdentifier("channels.subredditList")
    }
    .onDisappear { savePendingChanges() }
  }

  private var canAdd: Bool {
    inputValidation.canAdd
  }

  private var inputValidation: SubredditInputValidation {
    SubredditInputValidation.evaluate(newSubredditName, subreddits: subreddits)
  }

  private var feedbackMessage: (text: String, isError: Bool)? {
    if let addFailureMessage {
      return (addFailureMessage, true)
    }

    switch inputValidation.feedback {
    case .error(let message):
      return (message, true)
    case .preview(let message):
      return (message, false)
    case nil:
      return nil
    }
  }

  private func addSubreddit() {
    switch SubredditPersistenceActions.addSubreddit(
      named: newSubredditName,
      subreddits: subreddits,
      modelContext: modelContext,
      heuristicsStore: heuristicsStore,
      defaultLeadTimeMinutes: defaultLeadTimeMinutes
    ) {
    case .success(let subreddit):
      newSubredditName = ""
      addFailureMessage = nil
      withAnimation(.easeInOut(duration: 0.2)) {
        expandedSubredditId = subreddit.id
      }
    case .failure(let error):
      addFailureMessage = error.message
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

}
