import SwiftUI

struct PostHandoffView: View {
  static let copyTitleAccessibilityLabel = "Copy post title"
  static let copyBodyAccessibilityLabel = "Copy post body"
  static let copyLinksAccessibilityLabel = "Copy post links"
  static let copyAllAccessibilityLabel = "Copy full post text"
  static let openSubmitAccessibilityLabel = "Open Reddit submit page"

  let capture: Capture
  var checklistItems: [String] = []
  let onCopyTitle: () -> Bool
  let onCopyBody: () -> Bool
  let onCopyLinks: () -> Bool
  let onCopyAll: () -> Bool
  let onOpenSubmit: () -> Void
  let onMarkPosted: () -> Void
  let onClose: () -> Void

  @State private var statusMessage: String?

  var body: some View {
    VStack(spacing: 0) {
      header
      Divider()
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          postSection
          destinationSection
          materialsSection
          checklistSection
        }
        .padding(20)
      }
      Divider()
      if let statusMessage {
        statusBar(statusMessage)
        Divider()
      }
      footer
    }
    .frame(width: 560, height: 620)
    .background(AppColors.popoverBg)
  }

  private var header: some View {
    HStack(spacing: 12) {
      Image(systemName: "paperplane")
        .font(.system(size: 18, weight: .semibold))
        .foregroundStyle(AppColors.redditOrange)
        .frame(width: 28, height: 28)

      VStack(alignment: .leading, spacing: 2) {
        Text("Post Handoff")
          .font(.system(size: 15, weight: .semibold))
        Text(primarySubredditText)
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
      }

      Spacer()

      Button(action: onClose) {
        Image(systemName: "xmark")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(.secondary)
          .frame(width: 26, height: 26)
      }
      .buttonStyle(.plain)
      .help("Close")
      .accessibilityLabel("Close post handoff")
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 14)
  }

  private var postSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      sectionHeader("Post")

      VStack(alignment: .leading, spacing: 12) {
        handoffField(
          title: "Title",
          value: titleText.isEmpty ? "No title saved" : titleText,
          isPlaceholder: titleText.isEmpty,
          copyLabel: Self.copyTitleAccessibilityLabel,
          onCopy: { runCopy(onCopyTitle, successMessage: "Title copied") }
        )

        handoffField(
          title: "Body",
          value: bodyText.isEmpty ? "No body text saved" : bodyText,
          isPlaceholder: bodyText.isEmpty,
          lineLimit: 8,
          copyLabel: Self.copyBodyAccessibilityLabel,
          onCopy: { runCopy(onCopyBody, successMessage: "Body copied") }
        )
      }
    }
  }

  private var destinationSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      sectionHeader("Destination")

      if capture.subreddits.isEmpty {
        Text("No subreddit selected")
          .font(.system(size: 12))
          .foregroundStyle(.secondary)
      } else {
        FlowLayout(spacing: 6) {
          ForEach(sortedSubreddits, id: \.id) { subreddit in
            Text(subreddit.name)
              .font(.system(size: 11, weight: .medium))
              .foregroundStyle(AppColors.redditOrange)
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(AppColors.redditOrange.opacity(0.1))
              .clipShape(RoundedRectangle(cornerRadius: 6))
          }
        }
      }
    }
  }

  private var materialsSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        sectionHeader("Supporting Material")
        Spacer()
        if !linksText.isEmpty {
          iconButton(
            systemName: "link",
            label: Self.copyLinksAccessibilityLabel,
            action: { runCopy(onCopyLinks, successMessage: "Links copied") }
          )
        }
      }

      if capture.links.isEmpty && capture.mediaRefs.isEmpty && notesText.isEmpty {
        Text("No links, media, or notes attached")
          .font(.system(size: 12))
          .foregroundStyle(.secondary)
      } else {
        VStack(alignment: .leading, spacing: 10) {
          if !capture.links.isEmpty {
            summaryList(title: "Links", values: cleanedLinks)
          }
          if !capture.mediaRefs.isEmpty {
            summaryList(title: "Media", values: capture.mediaRefs)
          }
          if !notesText.isEmpty {
            handoffField(title: "Notes", value: notesText, lineLimit: 5)
          }
        }
      }
    }
  }

  private var checklistSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      sectionHeader("Checklist")

      if checklistItems.isEmpty {
        VStack(alignment: .leading, spacing: 6) {
          checklistRow("Review this subreddit's rules before posting")
          checklistRow("Confirm title/body formatting in Reddit's composer")
          checklistRow("Attach media manually if Reddit requires an upload")
        }
      } else {
        VStack(alignment: .leading, spacing: 6) {
          ForEach(checklistItems, id: \.self) { item in
            checklistRow(item)
          }
        }
      }
    }
  }

  private var footer: some View {
    HStack(spacing: 10) {
      Button(action: { runCopy(onCopyAll, successMessage: "Post handoff copied") }) {
        Label("Copy All", systemImage: "doc.on.doc")
      }
      .help(Self.copyAllAccessibilityLabel)
      .accessibilityLabel(Self.copyAllAccessibilityLabel)

      Spacer()

      Button(action: onMarkPosted) {
        Label("Mark Posted", systemImage: "checkmark.circle")
      }

      Button(action: onOpenSubmit) {
        Label("Open Reddit", systemImage: "arrow.up.right.square")
      }
      .keyboardShortcut(.defaultAction)
      .help(Self.openSubmitAccessibilityLabel)
      .accessibilityLabel(Self.openSubmitAccessibilityLabel)
    }
    .font(.system(size: 12, weight: .medium))
    .padding(.horizontal, 20)
    .padding(.vertical, 14)
  }

  private func statusBar(_ message: String) -> some View {
    HStack(spacing: 6) {
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(AppColors.redditOrange)
      Text(message)
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.secondary)
      Spacer()
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 8)
  }

  private func sectionHeader(_ title: String) -> some View {
    Text(title)
      .font(.system(size: 12, weight: .semibold))
      .foregroundStyle(.primary)
  }

  private func handoffField(
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

  private func summaryList(title: String, values: [String]) -> some View {
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

  private func checklistRow(_ text: String) -> some View {
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

  private func iconButton(systemName: String, label: String, action: @escaping () -> Void)
    -> some View
  {
    Button(action: action) {
      Image(systemName: systemName)
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.secondary)
        .frame(width: 22, height: 20)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .help(label)
    .accessibilityLabel(label)
  }

  private func runCopy(_ action: () -> Bool, successMessage: String) {
    statusMessage = action() ? successMessage : "Copy failed"
  }

  private var titleText: String {
    RedditPostingActions.titleText(for: capture)
  }

  private var bodyText: String {
    capture.text.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var linksText: String {
    RedditPostingActions.linksText(for: capture)
  }

  private var notesText: String {
    capture.notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
  }

  private var cleanedLinks: [String] {
    capture.links
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }

  private var sortedSubreddits: [Subreddit] {
    capture.subreddits.sorted {
      if $0.sortOrder == $1.sortOrder {
        return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
      }
      return $0.sortOrder < $1.sortOrder
    }
  }

  private var primarySubredditText: String {
    guard let subreddit = sortedSubreddits.first else { return "Choose a subreddit before posting" }
    if sortedSubreddits.count == 1 { return subreddit.name }
    return "\(subreddit.name) + \(sortedSubreddits.count - 1) more"
  }
}
