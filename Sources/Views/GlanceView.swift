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
                        stickerSectionLabel("Queue \u{00B7} \(queued.count)")

                        ForEach(queued, id: \.id) { capture in
                            glanceCard(capture: capture)
                                .onTapGesture(perform: onCaptureCardTap)
                        }
                    }

                    if upcomingWindows.count > 1 {
                        stickerSectionLabel("Upcoming")

                        ForEach(Array(upcomingWindows.prefix(3).enumerated()), id: \.offset) { _, window in
                            eventDot(window: window)
                        }
                    }
                }
                .padding(10)
            }

            Button(action: onNewCapture) {
                Text("+ New Capture")
                    .stickerButton(bgColor: StickerColors.reddit)
            }
            .buttonStyle(.plain)
            .padding(10)
        }
    }

    private func alertBanner(window: TimingEngine.UpcomingWindow) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text("\u{23F0}")
                Text(window.event.name)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(StickerColors.reddit)
            }
            if let sub = window.event.subreddit {
                Text("\(sub.name) \u{00B7} \(window.matchingCaptureCount) ready")
                    .font(.system(size: 10))
                    .foregroundStyle(StickerColors.textSecondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .stickerCard(borderColor: StickerColors.reddit)
    }

    private func glanceCard(capture: Capture) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(capture.project?.name ?? "Unknown")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(StickerColors.textPrimary)
            Text(capture.text)
                .font(.system(size: 10))
                .foregroundStyle(StickerColors.textSecondary)
                .lineLimit(1)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .stickerCard()
    }

    private func eventDot(window: TimingEngine.UpcomingWindow) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(window.urgency.color)
                .frame(width: 6, height: 6)
            Text("\(window.event.name) \u{00B7} \(window.event.subreddit?.name ?? "")")
                .font(.system(size: 10))
                .foregroundStyle(StickerColors.textSecondary)
                .lineLimit(1)
        }
    }

}
