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
  static let viewModeAccessibilityIdentifier = "planner.viewMode"
  static let rowActionHitSize: CGFloat = 28

  @Environment(\.modelContext) private var modelContext
  @Query(sort: \Capture.createdAt, order: .reverse) private var captures: [Capture]
  @Query(sort: \Subreddit.sortOrder) private var subreddits: [Subreddit]

  @State private var timingEngine = TimingEngine()
  @State var eventLoadResult = PlannerEventLoadResult(
    events: [],
    oneOffCount: 0,
    recurringCount: 0,
    limitPerKind: PlannerEventLoader.defaultLimitPerKind
  )
  @State var visibleWindowLimit = 50
  @State private var mode = PlannerMode.list
  @State private var loadError: String?
  private let refreshTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

  var visibleWindows: [TimingEngine.UpcomingWindow] {
    Array(timingEngine.upcomingWindows.prefix(visibleWindowLimit))
  }

  var dayGroups: [PlannerDayGroup] {
    PlannerPresentation.dayGroups(from: visibleWindows)
  }

  var calendarDays: [PlannerCalendarDay] {
    PlannerPresentation.calendarDays(from: timingEngine.upcomingWindows)
  }

  var hasMoreWindows: Bool {
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
      .accessibilityIdentifier(Self.viewModeAccessibilityIdentifier)
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

  func timeText(for date: Date) -> String {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    formatter.dateStyle = .none
    return formatter.string(from: date)
  }

  func refreshTiming() {
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
