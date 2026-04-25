import SwiftUI

struct CaptureCardView: View {
    let capture: Capture
    let compact: Bool
    var onMarkPosted: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(capture.project?.name ?? "Unknown")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(StickerColors.textPrimary)
                Spacer()
                HStack(spacing: 4) {
                    ForEach(capture.subreddits, id: \.id) { sub in
                        Text(sub.name)
                            .foregroundStyle(StickerColors.reddit)
                            .stickerBadge(color: StickerColors.reddit)
                    }
                }
            }

            Text(capture.text)
                .font(.system(size: 11))
                .foregroundStyle(StickerColors.textSecondary)
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
        .stickerCard()
    }

    private var captureFooter: some View {
        let isQueued = capture.status == .queued
        let statusColor = isQueued ? Color(nsColor: AppColors.green) : StickerColors.textSecondary
        return HStack {
            Text(capture.createdAt, style: .relative)
                .font(.system(size: 10))
                .foregroundStyle(StickerColors.textSecondary)
            Spacer()
            if isQueued, let onMarkPosted {
                Button("Mark Posted", action: onMarkPosted)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color(nsColor: AppColors.green))
            }
            Text(capture.status.rawValue)
                .foregroundStyle(statusColor)
                .stickerBadge(color: isQueued ? Color(nsColor: AppColors.green) : StickerColors.border)
        }
    }

    private var mediaThumbnail: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(StickerColors.card)
            .frame(width: 36, height: 36)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(StickerColors.border, lineWidth: 1)
            )
            .overlay(
                Image(systemName: "photo")
                    .font(.system(size: 12))
                    .foregroundStyle(StickerColors.textSecondary)
            )
    }
}
