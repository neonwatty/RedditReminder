import SwiftUI

struct PostedListView: View {
    let captures: [Capture]
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
                Text(capture.text)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
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
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(.green)
                .padding(.top, 4)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .contextMenu {
            if let onDelete {
                Button("Delete", role: .destructive) { onDelete(capture) }
            }
        }
    }
}
