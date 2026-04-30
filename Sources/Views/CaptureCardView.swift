import SwiftData
import SwiftUI

struct CaptureCardView: View {
  nonisolated static let copyTextAccessibilityLabel = "Copy post text"
  nonisolated static let openHandoffAccessibilityLabel = "Prepare post handoff"
  nonisolated static let openSubmitAccessibilityLabel = "Open Reddit submit page"
  nonisolated static let markPostedAccessibilityLabel = "Mark as posted"
  nonisolated static let deleteAccessibilityLabel = "Delete capture"

  let capture: Capture
  var urgency: UrgencyLevel = .none
  var nextWindowText: String? = nil
  var onTap: (() -> Void)? = nil
  var onOpenHandoff: (() -> Void)? = nil
  var onCopyText: (() -> Void)? = nil
  var onOpenSubmit: (() -> Void)? = nil
  var onMarkPosted: (() -> Void)? = nil
  var onDelete: (() -> Void)? = nil

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Button(action: { onTap?() }) {
        captureSummary
      }
      .buttonStyle(.plain)
      .contentShape(Rectangle())

      Spacer(minLength: 0)

      HStack(spacing: 8) {
        if let onOpenHandoff {
          actionButton(
            systemName: "paperplane",
            label: Self.openHandoffAccessibilityLabel,
            action: onOpenHandoff
          )
        }

        if let onCopyText {
          actionButton(
            systemName: "doc.on.doc",
            label: Self.copyTextAccessibilityLabel,
            action: onCopyText
          )
        }

        if let onOpenSubmit {
          actionButton(
            systemName: "arrow.up.right.square",
            label: Self.openSubmitAccessibilityLabel,
            action: onOpenSubmit
          )
        }

        if let onMarkPosted {
          actionButton(
            systemName: "checkmark.circle",
            label: Self.markPostedAccessibilityLabel,
            action: onMarkPosted
          )
        }

        if let onDelete {
          actionButton(
            systemName: "trash",
            label: Self.deleteAccessibilityLabel,
            action: onDelete
          )
        }

        if let dotColor = urgencyDotColor {
          Circle()
            .fill(dotColor)
            .frame(width: 7, height: 7)
            .padding(.top, 6)
            .help(UrgencyPresentation.label(for: urgency))
            .accessibilityLabel(UrgencyPresentation.accessibilityLabel(for: urgency))
        }
      }
    }
    .padding(.vertical, 10)
    .padding(.horizontal, 16)
    .contextMenu {
      if let onTap { Button("Edit") { onTap() } }
      if let onOpenHandoff { Button("Prepare Post") { onOpenHandoff() } }
      if let onCopyText { Button("Copy Post Text") { onCopyText() } }
      if let onOpenSubmit { Button("Open Reddit Submit Page") { onOpenSubmit() } }
      if let onMarkPosted { Button("Mark as Posted") { onMarkPosted() } }
      if onTap != nil || onOpenHandoff != nil || onCopyText != nil || onOpenSubmit != nil
        || onMarkPosted != nil
      {
        Divider()
      }
      if let onDelete { Button("Delete", role: .destructive) { onDelete() } }
    }
  }

  private var captureSummary: some View {
    VStack(alignment: .leading, spacing: 4) {
      if let title = capture.title, !title.isEmpty {
        Text(title)
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(.primary)
          .lineLimit(1)
        if !capture.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          Text(capture.text)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }
      } else {
        Text(capture.text)
          .font(.system(size: 12))
          .foregroundStyle(.primary)
          .lineLimit(2)
      }

      HStack(spacing: 6) {
        if let subredditSummary {
          Text(subredditSummary)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(AppColors.redditOrange)
            .lineLimit(1)
        }

        if !capture.links.isEmpty || !capture.mediaRefs.isEmpty || capture.notes != nil {
          Text("·")
            .font(.system(size: 9))
            .foregroundStyle(.secondary)
          Text(attachmentSummary)
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
        }

        if let nextWindowText {
          Text("·")
            .font(.system(size: 9))
            .foregroundStyle(.secondary)
          Text(nextWindowText)
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
        }
      }
    }
  }

  private func actionButton(systemName: String, label: String, action: @escaping () -> Void)
    -> some View
  {
    Button(action: action) {
      Label(label, systemImage: systemName)
        .labelStyle(.iconOnly)
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.secondary)
        .frame(width: 18, height: 18)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .help(label)
    .accessibilityLabel(label)
    .accessibilityIdentifier("captureCard.\(label.identifierSuffix)")
  }

  private var urgencyDotColor: Color? {
    UrgencyPresentation.color(for: urgency)
  }

  private var attachmentSummary: String {
    var parts: [String] = []
    if !capture.links.isEmpty {
      parts.append("\(capture.links.count) link\(capture.links.count == 1 ? "" : "s")")
    }
    if !capture.mediaRefs.isEmpty {
      parts.append("\(capture.mediaRefs.count) image\(capture.mediaRefs.count == 1 ? "" : "s")")
    }
    if capture.notes != nil {
      parts.append("notes")
    }
    return parts.joined(separator: " · ")
  }

  private var subredditSummary: String? {
    CaptureHelpers.subredditSummary(for: capture.subreddits)
  }
}

extension String {
  fileprivate var identifierSuffix: String {
    lowercased()
      .split { !$0.isLetter && !$0.isNumber }
      .joined(separator: ".")
  }
}
