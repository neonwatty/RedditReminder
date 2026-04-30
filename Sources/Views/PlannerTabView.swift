import SwiftData
import SwiftUI

struct PlannerTabView: View {
  @Query private var allEvents: [SubredditEvent]
  @Query(sort: \Capture.createdAt, order: .reverse) private var captures: [Capture]

  @State private var timingEngine = TimingEngine()
  private let refreshTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

  private var activeEvents: [SubredditEvent] {
    PopoverTimingPresentation.activeEvents(from: allEvents)
  }

  private var dayGroups: [PlannerDayGroup] {
    PlannerPresentation.dayGroups(from: timingEngine.upcomingWindows)
  }

  var body: some View {
    VStack(spacing: 0) {
      header
      Divider()
      if dayGroups.isEmpty {
        emptyState
      } else {
        ScrollView {
          VStack(alignment: .leading, spacing: 14) {
            ForEach(dayGroups, id: \.day) { group in
              dayGroup(group)
            }
          }
          .padding(14)
        }
      }
    }
    .onAppear(perform: refreshTiming)
    .onChange(of: PopoverTimingPresentation.eventTimingSignature(from: allEvents)) {
      refreshTiming()
    }
    .onChange(of: PopoverTimingPresentation.captureTimingSignature(from: captures)) {
      refreshTiming()
    }
    .onReceive(refreshTimer) { _ in
      refreshTiming()
    }
  }

  private var header: some View {
    HStack {
      VStack(alignment: .leading, spacing: 2) {
        Text("7-day planner")
          .font(.system(size: 13, weight: .semibold))
        Text("Upcoming posting windows and queue readiness")
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
      }
      Spacer()
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
  }

  private var emptyState: some View {
    VStack(spacing: 8) {
      Spacer()
      Text("No posting windows this week")
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.secondary)
      Text("Add channels or adjust peak windows to populate the planner")
        .font(.system(size: 11))
        .foregroundStyle(.tertiary)
      Spacer()
    }
    .frame(maxWidth: .infinity)
  }

  private func dayGroup(_ group: PlannerDayGroup) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(group.title.uppercased())
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(.secondary)
        .tracking(0.3)

      VStack(spacing: 0) {
        ForEach(group.windows, id: \.event.id) { window in
          plannerRow(window)
          if window.event.id != group.windows.last?.event.id {
            Divider().padding(.leading, 10)
          }
        }
      }
      .background(.quaternary.opacity(0.22))
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
      )
    }
  }

  private func plannerRow(_ window: TimingEngine.UpcomingWindow) -> some View {
    HStack(alignment: .top, spacing: 10) {
      urgencyDot(for: window.urgency)
        .padding(.top, 5)

      VStack(alignment: .leading, spacing: 3) {
        Text(EventBannerView.title(for: window))
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(.primary)
          .lineLimit(1)

        HStack(spacing: 5) {
          Text(timeText(for: window.eventDate))
          Text("·")
          Text(PlannerPresentation.readinessText(for: window.matchingCaptureCount))
            .foregroundStyle(window.matchingCaptureCount == 0 ? AppColors.redditOrange : .secondary)
        }
        .font(.system(size: 10))
        .foregroundStyle(.secondary)
      }

      Spacer(minLength: 0)

      Text(window.event.isGeneratedFromHeuristics ? "Auto" : "Manual")
        .font(.system(size: 9, weight: .semibold))
        .foregroundStyle(
          window.event.isGeneratedFromHeuristics ? AppColors.redditOrange : .secondary
        )
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
          window.event.isGeneratedFromHeuristics
            ? AppColors.redditOrange.opacity(0.10) : Color.clear
        )
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }
    .padding(10)
  }

  private func urgencyDot(for urgency: UrgencyLevel) -> some View {
    Circle()
      .fill(UrgencyPresentation.color(for: urgency) ?? Color.secondary.opacity(0.35))
      .frame(width: 7, height: 7)
      .help(UrgencyPresentation.label(for: urgency))
  }

  private func timeText(for date: Date) -> String {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    formatter.dateStyle = .none
    return formatter.string(from: date)
  }

  private func refreshTiming() {
    timingEngine.refresh(events: activeEvents, captures: captures)
  }
}
