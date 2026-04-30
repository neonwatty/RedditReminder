import SwiftUI

struct PostedListView: View {
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
          Text(capture.text)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .lineLimit(2)
        } else {
          Text(capture.text)
            .font(.system(size: 12))
            .foregroundStyle(.primary)
            .lineLimit(2)
        }
        HStack(spacing: 6) {
          if let sub = capture.subreddits.first {
            Text(sub.name)
              .font(.system(size: 10, weight: .medium))
              .foregroundStyle(AppColors.redditOrange)
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
          Button(action: { onOpenPostedURL(capture) }) {
            Image(systemName: "arrow.up.right.square")
              .font(.system(size: 12, weight: .medium))
              .foregroundStyle(.secondary)
              .frame(width: 18, height: 18)
          }
          .buttonStyle(.plain)
          .help("Open posted link")
          .accessibilityLabel("Open posted link")
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
}
