import SwiftData
import SwiftUI

struct ChannelsTabView: View {
  let notificationService: NotificationService
  let heuristicsStore: HeuristicsStore
  var onCreateCapture: (Subreddit?) -> Void = { _ in }

  static let setupTitleText = "Add a posting channel"
  static let firstRunSetupText =
    "Start with a subreddit so captures have a destination and reminders can use posting windows."
  static let returningSetupText = "Add another subreddit when you want reminders for a new channel."
  static let firstChannelAddedText =
    "Posting windows were generated for this channel. Create your first capture when you are ready."
  static let createFirstCaptureButtonText = "Create first capture"
  static let addSubredditPlaceholder = "Subreddit name"
  static let addSubredditButtonText = "Add channel"
  static let emptyListText = "Added channels will appear here."
  static let expandsNewSubredditAfterAdd = false

  @Query(sort: \Subreddit.sortOrder) private var subreddits: [Subreddit]
  @Environment(\.modelContext) private var modelContext

  @State private var expandedSubredditId: UUID?
  @State private var newSubredditName = ""
  @State private var addFailureMessage: String?
  @State private var didAddFirstChannel = false
  @State private var firstAddedSubreddit: Subreddit?
  @State private var draggingSubreddit: Subreddit?
  @AppStorage(SettingsKey.defaultLeadTimeMinutes) private var defaultLeadTimeMinutes: Int = 60

  var body: some View {
    VStack(spacing: 0) {
      VStack(alignment: .leading, spacing: 10) {
        VStack(alignment: .leading, spacing: 3) {
          Text(Self.setupTitleText)
            .font(.system(size: 13, weight: .semibold))
          Text(subreddits.isEmpty ? Self.firstRunSetupText : Self.returningSetupText)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }

        HStack(spacing: 8) {
          addSubredditField
          addSubredditButton
        }
        .frame(maxWidth: .infinity)

        if let feedbackMessage {
          Text(feedbackMessage.text)
            .font(.system(size: 10))
            .foregroundStyle(feedbackMessage.isError ? .red : .secondary)
        }

        if didAddFirstChannel {
          firstChannelNextStep
        }
      }
      .padding(14)

      Divider()

      ScrollView {
        VStack(spacing: 8) {
          if subreddits.isEmpty {
            Text(Self.emptyListText)
              .font(.system(size: 11))
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.vertical, 6)
          }

          ForEach(subreddits, id: \.id) { sub in
            SubredditRow(
              sub: sub,
              peakInfo: heuristicsStore.peakInfo(for: sub),
              isExpanded: expandedSubredditId == sub.id,
              onToggle: { toggleExpanded(sub) },
              onDelete: { deleteSubreddit(sub) },
              onMoveUp: moveUpAction(for: sub),
              onMoveDown: moveDownAction(for: sub)
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

  private var addSubredditField: some View {
    TextField(Self.addSubredditPlaceholder, text: $newSubredditName)
      .font(.system(size: 12))
      .textFieldStyle(.plain)
      .padding(.horizontal, 10)
      .padding(.vertical, 8)
      .frame(minHeight: 32)
      .inputFieldStyle(cornerRadius: 7)
      .accessibilityLabel("Subreddit name")
      .accessibilityIdentifier("channels.addSubreddit.textField")
      .onChange(of: newSubredditName) {
        addFailureMessage = nil
      }
      .onSubmit { addSubreddit() }
  }

  private var addSubredditButton: some View {
    Button(action: addSubreddit) {
      Label(Self.addSubredditButtonText, systemImage: "plus")
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(canAdd ? .white : .secondary)
        .frame(minWidth: 112, minHeight: 32)
        .padding(.horizontal, 2)
        .background(canAdd ? AppColors.redditOrange : Color(NSColor.separatorColor).opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }
    .buttonStyle(.plain)
    .disabled(!canAdd)
    .accessibilityLabel(Self.addSubredditButtonText)
    .accessibilityIdentifier("channels.addSubreddit.button")
  }

  private var firstChannelNextStep: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(Self.firstChannelAddedText)
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      Button(action: { onCreateCapture(firstAddedSubreddit) }) {
        Label(Self.createFirstCaptureButtonText, systemImage: "text.badge.plus")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(AppColors.redditOrange)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(Self.createFirstCaptureButtonText)
      .accessibilityIdentifier("channels.createFirstCapture")
    }
    .padding(10)
    .background(AppColors.redditOrange.opacity(0.08))
    .clipShape(RoundedRectangle(cornerRadius: 8))
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
    let wasFirstChannel = subreddits.isEmpty
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
      didAddFirstChannel = wasFirstChannel
      firstAddedSubreddit = wasFirstChannel ? subreddit : nil
      withAnimation(.easeInOut(duration: 0.2)) {
        expandedSubredditId = Self.expandsNewSubredditAfterAdd ? subreddit.id : nil
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

  private func moveUpAction(for sub: Subreddit) -> (() -> Void)? {
    guard let index = subreddits.firstIndex(where: { $0.id == sub.id }), index > 0 else {
      return nil
    }
    let target = subreddits[index - 1]
    return {
      _ = SubredditPersistenceActions.reorder(
        source: sub,
        target: target,
        subreddits: subreddits,
        modelContext: modelContext
      )
    }
  }

  private func moveDownAction(for sub: Subreddit) -> (() -> Void)? {
    guard let index = subreddits.firstIndex(where: { $0.id == sub.id }),
      index < subreddits.count - 1
    else {
      return nil
    }
    let target = subreddits[index + 1]
    return {
      _ = SubredditPersistenceActions.reorder(
        source: sub,
        target: target,
        subreddits: subreddits,
        modelContext: modelContext
      )
    }
  }

}
