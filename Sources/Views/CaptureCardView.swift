import SwiftUI
import SwiftData

struct CaptureCardView: View {
    let capture: Capture
    var urgency: UrgencyLevel = .none
    var onTap: (() -> Void)? = nil
    var onMarkPosted: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    var body: some View {
        Button(action: { onTap?() }) {
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

                        if !capture.links.isEmpty || !capture.mediaRefs.isEmpty || capture.notes != nil {
                            Text("·")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                            Text(attachmentSummary)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer(minLength: 0)

                if let dotColor = urgencyDotColor {
                    Circle()
                        .fill(dotColor)
                        .frame(width: 6, height: 6)
                        .padding(.top, 4)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Edit") { onTap?() }
            Button("Mark as Posted") { onMarkPosted?() }
            Divider()
            Button("Delete", role: .destructive) { onDelete?() }
        }
    }

    private var urgencyDotColor: Color? {
        switch urgency {
        case .active, .high: AppColors.redditOrange
        case .medium: Color.green
        case .none, .low, .expired: nil
        }
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
}
