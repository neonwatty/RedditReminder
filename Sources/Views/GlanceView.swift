import SwiftUI

struct GlanceView: View {
    let upcomingWindows: [TimingEngine.UpcomingWindow]
    let captures: [Capture]
    let onCaptureCardTap: () -> Void
    let onNewCapture: () -> Void

    @AppStorage("hasSeenShortcutOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if !hasSeenOnboarding {
                        ShortcutOnboardingCard(onDismiss: {
                            hasSeenOnboarding = true
                        })
                    }

                    if let next = upcomingWindows.first {
                        alertBanner(window: next)
                    }

                    let queued = captures.filter { $0.status == .queued }
                    if !queued.isEmpty {
                        sectionLabel("Queue · \(queued.count)")

                        ForEach(queued, id: \.id) { capture in
                            glanceCard(capture: capture)
                                .onTapGesture(perform: onCaptureCardTap)
                        }
                    }

                    if upcomingWindows.count > 1 {
                        sectionLabel("Upcoming")

                        ForEach(Array(upcomingWindows.prefix(3).enumerated()), id: \.offset) { _, window in
                            eventDot(window: window)
                        }
                    }
                }
                .padding(10)
            }

            Button(action: onNewCapture) {
                Text("+ New Capture")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color(nsColor: AppColors.reddit))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .padding(10)
        }
    }

    private func alertBanner(window: TimingEngine.UpcomingWindow) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text("⏰")
                Text(window.event.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(nsColor: AppColors.reddit))
            }
            if let sub = window.event.subreddit {
                Text("\(sub.name) · \(window.matchingCaptureCount) ready")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: AppColors.reddit).opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: AppColors.reddit).opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func glanceCard(capture: Capture) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(capture.project?.name ?? "Unknown")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.primary)
            Text(capture.text)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func eventDot(window: TimingEngine.UpcomingWindow) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(urgencyColor(window.urgency))
                .frame(width: 6, height: 6)
            Text("\(window.event.name) · \(window.event.subreddit?.name ?? "")")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .medium))
            .tracking(1.5)
            .textCase(.uppercase)
            .foregroundStyle(.tertiary)
    }

    private func urgencyColor(_ urgency: UrgencyLevel) -> Color {
        switch urgency {
        case .none: return .gray
        case .low: return Color(nsColor: AppColors.blue)
        case .medium: return Color(nsColor: AppColors.green)
        case .high, .active: return Color(nsColor: AppColors.reddit)
        case .expired: return .gray.opacity(0.5)
        }
    }
}
