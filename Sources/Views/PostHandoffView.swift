import SwiftUI

struct PostHandoffView: View {
  nonisolated static let copyTitleAccessibilityLabel = "Copy post title"
  nonisolated static let copyBodyAccessibilityLabel = "Copy post body"
  nonisolated static let copyLinksAccessibilityLabel = "Copy post links"
  nonisolated static let copyAllAccessibilityLabel = "Copy full post text"
  nonisolated static let openSubmitAccessibilityLabel = "Open Reddit submit page"

  let capture: Capture
  var checklistItems: [String] = []
  let onCopyTitle: () -> Bool
  let onCopyBody: () -> Bool
  let onCopyLinks: () -> Bool
  let onCopyAll: () -> Bool
  let onOpenSubmit: () -> Void
  let onMarkPosted: () -> Void
  let onClose: () -> Void
  var onMarkSubredditPosted: ((UUID) -> Void)? = nil
  var onMarkSubredditUnposted: ((UUID) -> Void)? = nil

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
        VStack(alignment: .leading, spacing: 6) {
          ForEach(sortedSubreddits, id: \.id) { subreddit in
            let isPosted = capture.postedSubredditIDs.contains(subreddit.id)
            HStack(spacing: 8) {
              Text(subreddit.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isPosted ? .secondary : AppColors.redditOrange)
                .strikethrough(isPosted)

              Spacer()

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
              .accessibilityLabel(isPosted ? "Unmark \(subreddit.name) as posted" : "Mark \(subreddit.name) as posted")
              .accessibilityIdentifier("postHandoff.subreddit.\(subreddit.name)")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isPosted ? Color(red: 0.13, green: 0.77, blue: 0.37).opacity(0.06) : AppColors.redditOrange.opacity(0.06))
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
      .accessibilityIdentifier("postHandoff.copyAll")

      Spacer()

      Button(action: onMarkPosted) {
        Label("Mark Posted", systemImage: "checkmark.circle")
      }
      .accessibilityLabel("Mark posted")
      .accessibilityIdentifier("postHandoff.markPosted")

      Button(action: onOpenSubmit) {
        Label("Open Reddit", systemImage: "arrow.up.right.square")
      }
      .keyboardShortcut(.defaultAction)
      .help(Self.openSubmitAccessibilityLabel)
      .accessibilityLabel(Self.openSubmitAccessibilityLabel)
      .accessibilityIdentifier("postHandoff.openSubmit")
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

  private func runCopy(_ action: () -> Bool, successMessage: String) {
    statusMessage = action() ? successMessage : "Copy failed"
  }
}
