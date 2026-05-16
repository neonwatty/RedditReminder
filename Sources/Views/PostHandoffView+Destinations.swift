import SwiftUI

extension PostHandoffView {
  var destinationSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      sectionHeader("Destination")

      if capture.subreddits.isEmpty {
        Text("No subreddit selected")
          .font(.system(size: 12))
          .foregroundStyle(.secondary)
      } else {
        VStack(alignment: .leading, spacing: 6) {
          ForEach(sortedSubreddits, id: \.id) { subreddit in
            destinationRow(subreddit)
          }
        }
      }
    }
  }

  @ViewBuilder
  var openSubmitControl: some View {
    if sortedSubreddits.count > 1 {
      Menu {
        ForEach(sortedSubreddits, id: \.id) { subreddit in
          Button(subreddit.name) {
            openSubmit(for: subreddit)
          }
        }
      } label: {
        Label("Choose Subreddit", systemImage: "arrow.up.right.square")
      }
      .help(Self.chooseSubmitDestinationAccessibilityLabel)
      .accessibilityLabel(Self.chooseSubmitDestinationAccessibilityLabel)
      .accessibilityIdentifier("postHandoff.chooseSubmitDestination")
    } else {
      Button(action: onOpenSubmit) {
        Label("Open Reddit", systemImage: "arrow.up.right.square")
      }
      .keyboardShortcut(.defaultAction)
      .help(Self.openSubmitAccessibilityLabel)
      .accessibilityLabel(Self.openSubmitAccessibilityLabel)
      .accessibilityIdentifier("postHandoff.openSubmit")
    }
  }

  private func destinationRow(_ subreddit: Subreddit) -> some View {
    let isPosted = capture.postedSubredditIDs.contains(subreddit.id)
    return HStack(spacing: 8) {
      Text(subreddit.name)
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(isPosted ? .secondary : AppColors.redditOrange)
        .strikethrough(isPosted)

      Spacer()

      openSubredditButton(subreddit)
      postedStateButton(subreddit, isPosted: isPosted)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .background(
      isPosted
        ? Color(red: 0.13, green: 0.77, blue: 0.37).opacity(0.06)
        : AppColors.redditOrange.opacity(0.06)
    )
    .clipShape(RoundedRectangle(cornerRadius: 6))
  }

  private func openSubredditButton(_ subreddit: Subreddit) -> some View {
    Button(action: { openSubmit(for: subreddit) }) {
      Image(systemName: "arrow.up.right.square")
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.secondary)
        .frame(width: Self.iconButtonMinimumHitSize, height: Self.iconButtonMinimumHitSize)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .help("Open Reddit for \(subreddit.name)")
    .accessibilityLabel("Open Reddit for \(subreddit.name)")
    .accessibilityIdentifier("postHandoff.openSubmit.\(subreddit.name.postHandoffIdentifierSuffix)")
  }

  private func postedStateButton(_ subreddit: Subreddit, isPosted: Bool) -> some View {
    Button(action: {
      if isPosted {
        onMarkSubredditUnposted?(subreddit.id)
      } else {
        onMarkSubredditPosted?(subreddit.id)
      }
    }) {
      HStack(spacing: 4) {
        Image(systemName: isPosted ? "checkmark.circle.fill" : "circle")
          .font(.system(size: 12))
        Text(isPosted ? "Posted" : "Not posted")
          .font(.system(size: 10, weight: .medium))
      }
      .foregroundStyle(isPosted ? Color(red: 0.13, green: 0.77, blue: 0.37) : .secondary)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(
      isPosted ? "Unmark \(subreddit.name) as posted" : "Mark \(subreddit.name) as posted"
    )
    .accessibilityIdentifier("postHandoff.subreddit.\(subreddit.name)")
  }

  private func openSubmit(for subreddit: Subreddit) {
    if let onOpenSubmitForSubreddit {
      onOpenSubmitForSubreddit(subreddit.id)
    } else {
      onOpenSubmit()
    }
  }
}
