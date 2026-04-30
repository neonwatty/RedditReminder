import SwiftUI

extension PostHandoffView {
  func sectionHeader(_ title: String) -> some View {
    Text(title)
      .font(.system(size: 12, weight: .semibold))
      .foregroundStyle(.primary)
  }

  func handoffField(
    title: String,
    value: String,
    isPlaceholder: Bool = false,
    lineLimit: Int? = nil,
    copyLabel: String? = nil,
    onCopy: (() -> Void)? = nil
  ) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text(title)
          .font(.system(size: 10, weight: .medium))
          .foregroundStyle(.secondary)
        Spacer()
        if let copyLabel, let onCopy {
          iconButton(systemName: "doc.on.doc", label: copyLabel, action: onCopy)
        }
      }

      Text(value)
        .font(.system(size: 12))
        .foregroundStyle(isPlaceholder ? .tertiary : .primary)
        .textSelection(.enabled)
        .lineLimit(lineLimit)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.quaternary.opacity(0.22))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
          RoundedRectangle(cornerRadius: 6)
            .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
        )
    }
  }

  func summaryList(title: String, values: [String]) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title)
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(.secondary)
      VStack(alignment: .leading, spacing: 4) {
        ForEach(values, id: \.self) { value in
          Text(value)
            .font(.system(size: 11))
            .foregroundStyle(.primary)
            .lineLimit(2)
            .textSelection(.enabled)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(10)
      .background(.quaternary.opacity(0.22))
      .clipShape(RoundedRectangle(cornerRadius: 6))
      .overlay(
        RoundedRectangle(cornerRadius: 6)
          .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
      )
    }
  }

  func checklistRow(_ text: String) -> some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: "circle")
        .font(.system(size: 9))
        .foregroundStyle(.secondary)
        .padding(.top, 3)
      Text(text)
        .font(.system(size: 12))
        .foregroundStyle(.primary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  func iconButton(systemName: String, label: String, action: @escaping () -> Void)
    -> some View
  {
    Button(action: action) {
      Label(label, systemImage: systemName)
        .labelStyle(.iconOnly)
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.secondary)
        .frame(width: 22, height: 20)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .help(label)
    .accessibilityLabel(label)
    .accessibilityIdentifier("postHandoff.\(label.postHandoffIdentifierSuffix)")
  }
}

extension PostHandoffView {
  var titleText: String {
    RedditPostingActions.titleText(for: capture)
  }

  var bodyText: String {
    capture.text.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  var linksText: String {
    RedditPostingActions.linksText(for: capture)
  }

  var notesText: String {
    capture.notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
  }

  var cleanedLinks: [String] {
    capture.links
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }

  var sortedSubreddits: [Subreddit] {
    capture.subreddits.sorted {
      if $0.sortOrder == $1.sortOrder {
        return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
      }
      return $0.sortOrder < $1.sortOrder
    }
  }

  var primarySubredditText: String {
    guard let subreddit = sortedSubreddits.first else { return "Choose a subreddit before posting" }
    if sortedSubreddits.count == 1 { return subreddit.name }
    return "\(subreddit.name) + \(sortedSubreddits.count - 1) more"
  }
}

extension String {
  fileprivate var postHandoffIdentifierSuffix: String {
    lowercased()
      .split { !$0.isLetter && !$0.isNumber }
      .joined(separator: ".")
  }
}
