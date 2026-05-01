import SwiftUI

struct EventBannerView: View {
  let upcomingWindows: [TimingEngine.UpcomingWindow]
  var onTap: ((TimingEngine.UpcomingWindow) -> Void)? = nil

  @State private var isExpanded: Bool = false

  var body: some View {
    if let next = upcomingWindows.first {
      VStack(spacing: 0) {
        Button(action: {
          if upcomingWindows.count > 1 {
            withAnimation(.easeInOut(duration: 0.15)) {
              isExpanded.toggle()
            }
          } else {
            onTap?(next)
          }
        }) {
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

                if let readyText = Self.readyCaptureText(count: next.matchingCaptureCount) {
                  Text("·")
                    .foregroundStyle(.secondary)
                  Text(readyText)
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

            if upcomingWindows.count > 1 {
              Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.trailing, 4)
            }
          }
          .padding(10)
          .background(AppColors.redditOrange.opacity(0.08))
          .clipShape(RoundedRectangle(cornerRadius: 8))
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(Self.accessibilityLabel(for: next, additionalWindowCount: upcomingWindows.count - 1))
        .accessibilityLabel(
          Self.accessibilityLabel(for: next, additionalWindowCount: upcomingWindows.count - 1)
        )

        if isExpanded {
          VStack(spacing: 2) {
            ForEach(upcomingWindows.dropFirst(), id: \.event.id) { window in
              Button(action: { onTap?(window) }) {
                HStack(spacing: 8) {
                  if let sub = window.event.subreddit {
                    Text(sub.name)
                      .font(.system(size: 11, weight: .medium))
                      .foregroundStyle(.primary)
                      .lineLimit(1)
                  } else {
                    Text(window.event.name)
                      .font(.system(size: 11, weight: .medium))
                      .foregroundStyle(.primary)
                      .lineLimit(1)
                  }

                  Spacer(minLength: 0)

                  Text(Self.relativeTime(window.eventDate))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)

                  if let readyText = Self.readyCaptureText(count: window.matchingCaptureCount) {
                    Text("·")
                      .font(.system(size: 9))
                      .foregroundStyle(.secondary)
                    Text(readyText)
                      .font(.system(size: 10))
                      .foregroundStyle(.secondary)
                  }

                  if let dotColor = UrgencyPresentation.color(for: window.urgency) {
                    Circle()
                      .fill(dotColor)
                      .frame(width: 6, height: 6)
                  }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
              }
              .buttonStyle(.plain)
              .accessibilityLabel(Self.accessibilityLabel(for: window, additionalWindowCount: 0))
            }
          }
          .padding(.top, 4)
          .transition(.opacity.combined(with: .move(edge: .top)))
        }
      }
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

  nonisolated static func readyCaptureText(count: Int) -> String? {
    guard count > 0 else { return nil }
    return "\(count) capture\(count == 1 ? "" : "s") ready"
  }

  static func title(for window: TimingEngine.UpcomingWindow) -> String {
    if let subreddit = window.event.subreddit {
      return "\(subreddit.name) — \(window.event.name)"
    }
    return window.event.name
  }

  static func accessibilityLabel(
    for window: TimingEngine.UpcomingWindow, additionalWindowCount: Int
  ) -> String {
    var parts = [
      "Upcoming posting window",
      title(for: window),
      UrgencyPresentation.label(for: window.urgency),
    ]

    if let readyText = readyCaptureText(count: window.matchingCaptureCount) {
      parts.append(readyText)
    }

    if additionalWindowCount > 0 {
      parts.append("\(additionalWindowCount) more window\(additionalWindowCount == 1 ? "" : "s")")
    }

    return parts.joined(separator: ", ")
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
        .background(
          event.isGeneratedFromHeuristics ? AppColors.redditOrange.opacity(0.10) : Color.clear
        )
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
          RoundedRectangle(cornerRadius: 4)
            .stroke(
              event.isGeneratedFromHeuristics
                ? AppColors.redditOrange : Color(NSColor.separatorColor), lineWidth: 0.5)
        )
    }
  }
}
