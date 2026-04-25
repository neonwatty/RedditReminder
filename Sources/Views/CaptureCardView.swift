import SwiftUI

struct CaptureCardView: View {
    let capture: Capture
    let compact: Bool
    var onMarkPosted: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(capture.project?.name ?? "Unknown")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
                HStack(spacing: 4) {
                    ForEach(capture.subreddits, id: \.id) { sub in
                        Text(sub.name)
                            .font(.system(size: 9))
                            .foregroundStyle(Color(nsColor: AppColors.reddit))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(nsColor: AppColors.reddit).opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
            }

            Text(capture.text)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(compact ? 1 : 3)

            if !compact && !capture.mediaRefs.isEmpty {
                HStack(spacing: 4) {
                    ForEach(capture.mediaRefs.prefix(4), id: \.self) { _ in
                        mediaThumbnail
                    }
                }
            }

            if !compact {
                captureFooter
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var captureFooter: some View {
        let isQueued = capture.status == .queued
        let statusColor = isQueued ? Color(nsColor: AppColors.green) : Color.secondary
        return HStack {
            Text(capture.createdAt, style: .relative)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            Spacer()
            if isQueued, let onMarkPosted {
                Button("Mark Posted", action: onMarkPosted)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color(nsColor: AppColors.green))
            }
            Text(capture.status.rawValue)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(statusColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(isQueued
                    ? Color(nsColor: AppColors.green).opacity(0.1)
                    : Color.white.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 3))
        }
    }

    private var mediaThumbnail: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.white.opacity(0.08))
            .frame(width: 36, height: 36)
            .overlay(
                Image(systemName: "photo")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            )
    }
}
