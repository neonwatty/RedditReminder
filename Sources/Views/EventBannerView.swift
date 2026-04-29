import SwiftUI

struct EventBannerView: View {
    let upcomingWindows: [TimingEngine.UpcomingWindow]
    var onTap: ((TimingEngine.UpcomingWindow) -> Void)? = nil

    var body: some View {
        if let next = upcomingWindows.first {
            Button(action: { onTap?(next) }) {
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(AppColors.redditOrange)
                        .frame(width: 3)
                        .padding(.vertical, 2)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("UPCOMING")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(AppColors.redditOrange)
                            .tracking(0.5)

                        if let sub = next.event.subreddit {
                            eventTitle("\(sub.name) — \(next.event.name)", event: next.event)
                        } else {
                            eventTitle(next.event.name, event: next.event)
                        }

                        HStack(spacing: 4) {
                            Text(Self.relativeTime(next.eventDate))
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)

                            if next.matchingCaptureCount > 0 {
                                Text("·")
                                    .foregroundStyle(.secondary)
                                Text("\(next.matchingCaptureCount) capture\(next.matchingCaptureCount == 1 ? "" : "s") ready")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }

                            if upcomingWindows.count > 1 {
                                Text("·")
                                    .foregroundStyle(.secondary)
                                Text("and \(upcomingWindows.count - 1) more")
                                    .font(.system(size: 10))
                                    .foregroundStyle(AppColors.redditOrange)
                            }
                        }
                    }
                    .padding(.leading, 10)

                    Spacer(minLength: 0)
                }
                .padding(10)
                .background(AppColors.redditOrange.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 4)
        }
    }

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    static func relativeTime(
        _ date: Date,
        relativeTo referenceDate: Date = Date(),
        formatter: RelativeDateTimeFormatter = EventBannerView.relativeDateFormatter
    ) -> String {
        formatter.localizedString(for: date, relativeTo: referenceDate)
    }

    private func eventTitle(_ title: String, event: SubredditEvent) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Text(event.isGeneratedFromHeuristics ? "Auto" : "Manual")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(event.isGeneratedFromHeuristics ? AppColors.redditOrange : .secondary)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(event.isGeneratedFromHeuristics ? AppColors.redditOrange.opacity(0.10) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(event.isGeneratedFromHeuristics ? AppColors.redditOrange : Color(NSColor.separatorColor), lineWidth: 0.5)
                )
        }
    }
}
