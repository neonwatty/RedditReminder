import SwiftUI

struct EventCardView: View {
    let window: TimingEngine.UpcomingWindow

    var body: some View {
        let isUrgent = window.urgency >= .high

        VStack(alignment: .leading, spacing: 3) {
            Text(window.event.name)
                .font(.system(size: 11, weight: isUrgent ? .bold : .regular))
                .foregroundStyle(isUrgent ? .primary : .secondary)

            if let sub = window.event.subreddit {
                Text("\(sub.name) · \(window.event.isRecurring ? "recurring" : "one-off")")
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
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isUrgent
            ? Color(nsColor: AppColors.reddit).opacity(0.08)
            : Color.white.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isUrgent
                    ? Color(nsColor: AppColors.reddit).opacity(0.3)
                    : Color.white.opacity(0.06),
                lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var urgencyColor: Color {
        switch window.urgency {
        case .active, .high: return Color(nsColor: AppColors.reddit)
        case .medium: return Color(nsColor: AppColors.green)
        case .low: return Color(nsColor: AppColors.blue)
        default: return .secondary
        }
    }
}
