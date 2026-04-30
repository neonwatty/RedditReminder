import SwiftUI

struct PostedListView: View {
  nonisolated static let openPostedLinkAccessibilityLabel = "Open posted link"
  nonisolated static let restoreAccessibilityLabel = "Move posted capture back to queue"
  nonisolated static let deleteAccessibilityLabel = "Delete posted capture"

  let captures: [Capture]
  var onOpenPostedURL: ((Capture) -> Void)? = nil
  var onRestore: ((Capture) -> Void)? = nil
  var onDelete: ((Capture) -> Void)? = nil

  var body: some View {
    ForEach(captures, id: \.id) { capture in
      row(capture)

      if capture.id != captures.last?.id {
        Divider().padding(.horizontal, 16)
      }
    }
  }

  private func row(_ capture: Capture) -> some View {
    HStack(alignment: .top, spacing: 10) {
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
          if let subredditSummary = CaptureHelpers.subredditSummary(for: capture.subreddits) {
            Text(subredditSummary)
              .font(.system(size: 10, weight: .medium))
              .foregroundStyle(AppColors.redditOrange)
              .lineLimit(1)
          }
          if let postedAt = capture.postedAt {
            Text("\u{00B7}").font(.system(size: 9)).foregroundStyle(.secondary)
            Text(postedAt, style: .relative)
              .font(.system(size: 10))
              .foregroundStyle(.secondary)
          }
          if capture.postedURL != nil {
            Text("\u{00B7}").font(.system(size: 9)).foregroundStyle(.secondary)
            Text("link saved")
              .font(.system(size: 10))
              .foregroundStyle(.secondary)
          }
        }
      }
      Spacer(minLength: 0)
      HStack(spacing: 8) {
        if let onOpenPostedURL, capture.postedURL != nil {
          actionButton(
            systemName: "arrow.up.right.square",
            label: Self.openPostedLinkAccessibilityLabel,
            identifier: "postedList.openPostedLink",
            action: { onOpenPostedURL(capture) }
          )
        }
        if let onRestore {
          actionButton(
            systemName: "arrow.uturn.backward",
            label: Self.restoreAccessibilityLabel,
            identifier: "postedList.restore",
            action: { onRestore(capture) }
          )
        }
        if let onDelete {
          actionButton(
            systemName: "trash",
            label: Self.deleteAccessibilityLabel,
            identifier: "postedList.delete",
            action: { onDelete(capture) }
          )
        }
        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: 12))
          .foregroundStyle(.green)
          .padding(.top, 4)
      }
    }
    .padding(.vertical, 10)
    .padding(.horizontal, 16)
    .contextMenu {
      if let onOpenPostedURL, capture.postedURL != nil {
        Button("Open Posted Link") { onOpenPostedURL(capture) }
      }
      if let onRestore {
        if onOpenPostedURL != nil, capture.postedURL != nil { Divider() }
        Button("Move back to Queue") { onRestore(capture) }
      }
      if let onDelete {
        if onRestore != nil { Divider() }
        Button("Delete", role: .destructive) { onDelete(capture) }
      }
    }
  }

  private func actionButton(
    systemName: String,
    label: String,
    identifier: String,
    action: @escaping () -> Void
  ) -> some View {
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
    .accessibilityIdentifier(identifier)
  }
}
