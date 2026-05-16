import SwiftData
import SwiftUI

struct PlannerTabView: View {
  private enum PlannerMode: String, CaseIterable, Identifiable {
    case list = "List"
    case calendar = "Calendar"

    var id: String { rawValue }
  }

  var onCreateCapture: AppRefreshAction = {}
  var onCreateCaptureForSubreddit: (Subreddit?) -> Void = { _ in }
  var onViewQueue: AppRefreshAction = {}
  var onEditChannels: AppRefreshAction = {}

  static let createCaptureActionText = "Create capture"
  static let viewQueueActionText = "View queue"
  static let editChannelsActionText = "Edit windows"

  @Environment(\.modelContext) private var modelContext
  @Query(sort: \Capture.createdAt, order: .reverse) private var captures: [Capture]
  @Query(sort: \Subreddit.sortOrder) private var subreddits: [Subreddit]

  @State private var timingEngine = TimingEngine()
  @State private var eventLoadResult = PlannerEventLoadResult(
    events: [],
    oneOffCount: 0,
    recurringCount: 0,
    limitPerKind: PlannerEventLoader.defaultLimitPerKind
  )
  @State private var visibleWindowLimit = 50
  @State private var mode = PlannerMode.list
  @State private var loadError: String?
  private let refreshTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

  private var visibleWindows: [TimingEngine.UpcomingWindow] {
    Array(timingEngine.upcomingWindows.prefix(visibleWindowLimit))
  }

  private var dayGroups: [PlannerDayGroup] {
    PlannerPresentation.dayGroups(from: visibleWindows)
  }

  private var calendarDays: [PlannerCalendarDay] {
    PlannerPresentation.calendarDays(from: timingEngine.upcomingWindows)
  }

  private var hasMoreWindows: Bool {
    visibleWindowLimit < timingEngine.upcomingWindows.count
  }

  var body: some View {
    VStack(spacing: 0) {
      header
      Divider()
      if let loadError {
        errorState(loadError)
      } else if timingEngine.upcomingWindows.isEmpty {
        emptyState
      } else if mode == .calendar {
        calendarView
      } else {
        listView
      }
    }
    .onAppear(perform: refreshTiming)
    .onChange(of: PopoverTimingPresentation.captureTimingSignature(from: captures)) {
      refreshTiming()
    }
    .onChange(of: PopoverTimingPresentation.subredditTimingSignature(from: subreddits)) {
      refreshTiming()
    }
    .onReceive(refreshTimer) { _ in
      refreshTiming()
    }
  }

  private var header: some View {
    HStack(alignment: .center, spacing: 12) {
      VStack(alignment: .leading, spacing: 2) {
        Text("7-day planner")
          .font(.system(size: 13, weight: .semibold))
        Text(headerDetailText)
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
      }
      Spacer()
      Picker("Planner view", selection: $mode) {
        ForEach(PlannerMode.allCases) { mode in
          Text(mode.rawValue).tag(mode)
        }
      }
      .labelsHidden()
      .pickerStyle(.segmented)
      .frame(width: 150)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
  }

  private var headerDetailText: String {
    let countText = "\(timingEngine.upcomingWindows.count) window\(timingEngine.upcomingWindows.count == 1 ? "" : "s")"
    if eventLoadResult.hitLimit {
      return "\(countText) from capped event scan"
    }
    return "\(countText) and queue readiness"
  }

  private var listView: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        if eventLoadResult.hitLimit {
          cappedFetchNotice
        }
        ForEach(dayGroups, id: \.day) { group in
          dayGroup(group)
        }
        if hasMoreWindows {
          Button("Load next 50 windows") {
            visibleWindowLimit += 50
          }
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(AppColors.redditOrange)
          .buttonStyle(.plain)
          .frame(maxWidth: .infinity, minHeight: 32)
        }
      }
      .padding(14)
    }
  }

  private var calendarView: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 12) {
        if eventLoadResult.hitLimit {
          cappedFetchNotice
        }
        LazyVGrid(
          columns: Array(repeating: GridItem(.flexible(minimum: 48), spacing: 6), count: 7),
          alignment: .leading,
          spacing: 6
        ) {
          ForEach(calendarDays, id: \.day) { day in
            calendarDayCell(day)
          }
        }
      }
      .padding(14)
    }
  }

  private var cappedFetchNotice: some View {
    Text(
      "Planner loaded \(eventLoadResult.loadedCount) candidate events. Narrow channels or archive old windows if expected events are missing."
    )
    .font(.system(size: 10))
    .foregroundStyle(.secondary)
    .padding(8)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.quaternary.opacity(0.22))
    .clipShape(RoundedRectangle(cornerRadius: 8))
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
      Button(Self.editChannelsActionText, action: onEditChannels)
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(AppColors.redditOrange)
        .buttonStyle(.plain)
      Spacer()
    }
    .frame(maxWidth: .infinity)
  }

  private func errorState(_ message: String) -> some View {
    VStack(spacing: 8) {
      Spacer()
      Text("Planner unavailable")
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.secondary)
      Text(message)
        .font(.system(size: 11))
        .foregroundStyle(.tertiary)
      Button("Retry", action: refreshTiming)
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(AppColors.redditOrange)
        .buttonStyle(.plain)
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

      VStack(alignment: .trailing, spacing: 5) {
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

        HStack(spacing: 8) {
          if window.matchingCaptureCount == 0 {
            Button(Self.createCaptureActionText) {
              onCreateCaptureForSubreddit(window.event.subreddit)
            }
            .accessibilityIdentifier(
              PlannerPresentation.createCaptureIdentifier(subredditId: window.event.subreddit?.id)
            )
          } else {
            Button(Self.viewQueueActionText, action: onViewQueue)
              .accessibilityIdentifier("planner.viewQueue")
          }
          Button(Self.editChannelsActionText, action: onEditChannels)
            .accessibilityIdentifier("planner.editChannels")
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(AppColors.redditOrange)
        .buttonStyle(.plain)
      }
    }
    .padding(10)
  }

  private func calendarDayCell(_ day: PlannerCalendarDay) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      VStack(alignment: .leading, spacing: 1) {
        Text(day.title)
          .font(.system(size: 9, weight: .semibold))
          .foregroundStyle(.secondary)
          .lineLimit(1)
        Text(day.dayNumber)
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(.primary)
      }

      if day.windows.isEmpty {
        Text("No windows")
          .font(.system(size: 9))
          .foregroundStyle(.tertiary)
          .lineLimit(1)
      } else {
        ForEach(day.windows.prefix(3), id: \.event.id) { window in
          calendarWindowPill(window)
        }
        if day.windows.count > 3 {
          Text("+\(day.windows.count - 3) more")
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(AppColors.redditOrange)
        }
      }
      Spacer(minLength: 0)
    }
    .padding(8)
    .frame(maxWidth: .infinity, minHeight: 126, alignment: .topLeading)
    .background(day.windows.isEmpty ? Color.clear : Color(NSColor.controlBackgroundColor))
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
    )
  }

  private func calendarWindowPill(_ window: TimingEngine.UpcomingWindow) -> some View {
    HStack(spacing: 4) {
      urgencyDot(for: window.urgency)
      Text(
        PlannerPresentation.calendarWindowLabel(
          subredditName: window.event.subreddit?.name,
          timeText: timeText(for: window.eventDate)
        )
      )
        .lineLimit(1)
    }
    .font(.system(size: 9, weight: .medium))
    .foregroundStyle(.secondary)
    .padding(.horizontal, 5)
    .padding(.vertical, 3)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(NSColor.controlBackgroundColor))
    .clipShape(RoundedRectangle(cornerRadius: 5))
    .help(EventBannerView.title(for: window))
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
    do {
      let result = try PlannerEventLoader.fetchUpcomingCandidates(context: modelContext)
      eventLoadResult = result
      loadError = nil
      timingEngine.refresh(events: result.events, captures: captures)
      visibleWindowLimit = min(max(50, visibleWindowLimit), max(50, timingEngine.upcomingWindows.count))
    } catch {
      loadError = error.localizedDescription
      timingEngine.refresh(events: [], captures: captures)
    }
  }
}
