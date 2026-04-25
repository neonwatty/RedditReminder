import SwiftUI

struct EventCardView: View {
    let window: TimingEngine.UpcomingWindow

    var body: some View {
        let isUrgent = window.urgency >= .high

        VStack(alignment: .leading, spacing: 3) {
            Text(window.event.name)
                .font(.system(size: 11, weight: isUrgent ? .heavy : .bold))
                .foregroundStyle(isUrgent ? StickerColors.textPrimary : StickerColors.textSecondary)

            if let sub = window.event.subreddit {
                Text("\(sub.name) \u{00B7} \(window.event.isRecurring ? "recurring" : "one-off")")
                    .font(.system(size: 10))
                    .foregroundStyle(urgencyColor)
            }

            if window.matchingCaptureCount > 0 {
                Text("\(window.matchingCaptureCount) captures ready")
                    .font(.system(size: 10))
                    .foregroundStyle(urgencyColor)
            } else {
                Text("No captures tagged yet")
                    .font(.system(size: 10))
                    .foregroundStyle(StickerColors.textSecondary)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .stickerCard(borderColor: isUrgent ? Color(nsColor: AppColors.reddit) : StickerColors.border)
    }

    private var urgencyColor: Color {
        switch window.urgency {
        case .active, .high: return Color(nsColor: AppColors.reddit)
        case .medium: return Color(nsColor: AppColors.green)
        case .low: return Color(nsColor: AppColors.blue)
        default: return StickerColors.textSecondary
        }
    }
}
