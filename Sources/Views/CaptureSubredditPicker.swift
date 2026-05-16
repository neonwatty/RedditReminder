import SwiftUI

struct CaptureSubredditPicker: View {
  let subreddits: [Subreddit]
  @Binding var selectedSubreddits: Set<UUID>
  var onAddSubreddit: () -> Void = {}

  static let emptyTitleText = "No channels yet"
  static let emptyDescriptionText = "Add a subreddit channel before saving this capture."
  static let addChannelButtonText = "Add channel"
  static let addChannelButtonAccessibilityIdentifier = "captureWindow.addChannel"

  var body: some View {
    if subreddits.isEmpty {
      VStack(alignment: .leading, spacing: 8) {
        Text(Self.emptyTitleText)
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(.primary)
        Text(Self.emptyDescriptionText)
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
        Button(action: onAddSubreddit) {
          Label(Self.addChannelButtonText, systemImage: "plus")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(AppColors.redditOrange)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Self.addChannelButtonText)
        .accessibilityIdentifier(Self.addChannelButtonAccessibilityIdentifier)
      }
      .padding(10)
      .frame(maxWidth: .infinity, alignment: .leading)
      .inputFieldStyle()
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier("captureWindow.noChannels")
    } else {
      Menu {
        ForEach(subreddits, id: \.id) { sub in
          Button(action: {
            if selectedSubreddits.contains(sub.id) {
              selectedSubreddits.remove(sub.id)
            } else {
              selectedSubreddits.insert(sub.id)
            }
          }) {
            HStack {
              Text(sub.name)
              if selectedSubreddits.contains(sub.id) {
                Image(systemName: "checkmark")
              }
            }
          }
          .accessibilityLabel(
            selectedSubreddits.contains(sub.id)
              ? "Deselect \(sub.name)"
              : "Select \(sub.name)"
          )
          .accessibilityIdentifier("captureWindow.subreddit.\(sub.id.uuidString)")
        }
      } label: {
        HStack {
          if selectedSubreddits.isEmpty {
            Text("Select subreddit...")
              .foregroundStyle(.secondary)
          } else {
            let names =
              subreddits
              .filter { selectedSubreddits.contains($0.id) }
              .map(\.name)
              .joined(separator: ", ")
            Text(names)
              .foregroundStyle(AppColors.redditOrange)
          }
          Spacer()
          Image(systemName: "chevron.down")
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
        }
        .font(.system(size: 12))
        .padding(8)
        .inputFieldStyle()
      }
      .menuStyle(.borderlessButton)
      .accessibilityLabel("Capture subreddits")
      .accessibilityIdentifier("captureWindow.subreddits")
    }
  }
}
