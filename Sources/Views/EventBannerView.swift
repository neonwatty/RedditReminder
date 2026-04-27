import SwiftUI

struct EventBannerView: View {
    let upcomingWindows: [TimingEngine.UpcomingWindow]
    var onTap: ((TimingEngine.UpcomingWindow) -> Void)? = nil

    private static let redditOrange = AppColors.redditOrange

    var body: some View {
        if let next = upcomingWindows.first {
            Button(action: { onTap?(next) }) {
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Self.redditOrange)
                        .frame(width: 3)
                        .padding(.vertical, 2)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("UPCOMING")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Self.redditOrange)
                            .tracking(0.5)

                        if let sub = next.event.subreddit {
                            Text("\(sub.name) — \(next.event.name)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                        } else {
                            Text(next.event.name)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                        }

                        HStack(spacing: 4) {
                            Text(relativeTime(next.eventDate))
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
                                    .foregroundStyle(Self.redditOrange)
                            }
                        }
                    }
                    .padding(.leading, 10)

                    Spacer(minLength: 0)
                }
                .padding(10)
                .background(Self.redditOrange.opacity(0.08))
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

    private func relativeTime(_ date: Date) -> String {
        Self.relativeDateFormatter.localizedString(for: date, relativeTo: Date())
    }
}
