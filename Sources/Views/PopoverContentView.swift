import SwiftData
import SwiftUI

enum PopoverRoute {
  case root
  case captureCreate
  case captureEdit(Capture)
  case postHandoff(Capture)
}

struct PopoverContentView: View {
  let menuBarController: MenuBarController
  let notificationService: NotificationService
  let heuristicsStore: HeuristicsStore
  let onAppStateChanged: AppRefreshAction
  let mediaStore = MediaStore()

  @Query(sort: \Capture.createdAt, order: .reverse) private var captures: [Capture]
  @Query(sort: \Subreddit.sortOrder) var subreddits: [Subreddit]
  @Environment(\.modelContext) var modelContext

  @State private var timingEngine = TimingEngine()
  @State var filterSubredditId: UUID?
  @State private var searchText: String = ""
  @State var toast: Toast?
  @State var toastTask: Task<Void, Never>?
  @State var selectedWorkspace: PopoverWorkspace = .queue
  @State var route: PopoverRoute = .root
  @State var handledNewCaptureRequestCount: Int = 0
  @State var handledPreferencesRequestCount: Int = 0
  @State var pendingCreateDraft: CaptureFormDraft?

  private var queuedCaptures: [Capture] { PopoverCaptureFiltering.queuedCaptures(from: captures) }
  private var postedCaptures: [Capture] { PopoverCaptureFiltering.postedCaptures(from: captures) }
  private var displayedCaptures: [Capture] {
    PopoverCaptureFiltering.displayedQueuedCaptures(
      from: captures,
      filterSubredditId: filterSubredditId,
      searchText: searchText
    )
  }
  private var displayedPostedCaptures: [Capture] {
    PopoverCaptureFiltering.displayedPostedCaptures(from: captures, searchText: searchText)
  }

  var body: some View {
    VStack(spacing: 0) {
      switch route {
      case .root:
        header
        if usesCaptureSearch && !captures.isEmpty { searchBar }
        workspaceContent
        footer
      case .captureCreate:
        captureForm(mode: .create)
      case .captureEdit(let capture):
        captureForm(mode: .edit(capture))
      case .postHandoff(let capture):
        postHandoff(capture)
      }
    }
    .overlay(alignment: .top) {
      if let toast {
        PopoverToastView(toast: toast)
      }
    }
    .background(.regularMaterial)
    .frame(width: 460).frame(maxHeight: (NSScreen.main?.visibleFrame.height ?? 800) * 0.85)
    .onAppear {
      handlePendingMenuRequests()
      refreshTiming()
    }
    .onChange(of: menuBarController.newCaptureRequestCount) {
      handleNewCaptureRequest()
    }
    .onChange(of: menuBarController.preferencesRequestCount) {
      handlePreferencesRequest()
    }
    .onChange(of: captureTimingSignature) {
      refreshTiming()
    }
    .onChange(of: subredditTimingSignature) {
      refreshTiming()
    }
  }

  private var captureTimingSignature: [String] {
    PopoverTimingPresentation.captureTimingSignature(from: captures)
  }

  private var subredditTimingSignature: [String] {
    PopoverTimingPresentation.subredditTimingSignature(from: subreddits)
  }

  private func refreshTiming() {
    guard let result = try? PlannerEventLoader.fetchUpcomingCandidates(context: modelContext) else {
      timingEngine.refresh(events: [], captures: captures)
      return
    }
    timingEngine.refresh(events: result.events, captures: captures)
  }

  // MARK: - Urgency

  private var urgencyBySubredditId: [UUID: UrgencyLevel] {
    PopoverTimingPresentation.urgencyBySubredditId(from: timingEngine.upcomingWindows)
  }

  // MARK: - Content

  private var usesCaptureSearch: Bool {
    selectedWorkspace == .queue || selectedWorkspace == .posted
  }

  @ViewBuilder
  private var workspaceContent: some View {
    switch selectedWorkspace {
    case .queue:
      queuedContent
    case .planner:
      PlannerTabView(
        onCreateCapture: openNewCapture,
        onCreateCaptureForSubreddit: { openNewCapture(for: $0) },
        onViewQueue: { selectedWorkspace = .queue },
        onEditChannels: { selectedWorkspace = .channels }
      )
    case .channels:
      ChannelsTabView(
        notificationService: notificationService,
        heuristicsStore: heuristicsStore,
        onCreateCapture: { openNewCapture(for: $0) }
      )
    case .projects:
      ProjectsTabView()
    case .posted:
      postedContent
    }
  }

  @ViewBuilder
  private var queuedContent: some View {
    if filterSubredditId != nil { filterBar }
    switch Self.queueContentPresentation(
      displayedCaptureCount: displayedCaptures.count,
      upcomingWindowCount: timingEngine.upcomingWindows.count,
      isFiltered: filterSubredditId != nil
    ) {
    case .onboarding:
      emptyState
    case .filteredEmpty:
      filteredEmptyState
    case .emptyWithWindows:
      ScrollView {
        VStack(spacing: 0) {
          EventBannerView(
            upcomingWindows: timingEngine.upcomingWindows,
            onTap: { window in
              let tappedId = window.event.subreddit?.id
              withAnimation(.easeInOut(duration: 0.15)) {
                filterSubredditId = filterSubredditId == tappedId ? nil : tappedId
              }
            })
          emptyQueueWithWindowsState
        }
      }
    case .list:
      ScrollView {
        VStack(spacing: 0) {
          EventBannerView(
            upcomingWindows: timingEngine.upcomingWindows,
            onTap: { window in
              let tappedId = window.event.subreddit?.id
              withAnimation(.easeInOut(duration: 0.15)) {
                filterSubredditId = filterSubredditId == tappedId ? nil : tappedId
              }
            })
          captureList(displayedCaptures)
        }
      }
    }
  }

  @ViewBuilder
  private var postedContent: some View {
    if displayedPostedCaptures.isEmpty {
      VStack(spacing: 12) {
        Spacer()
        Text(
          searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "No posted captures yet" : "No posted captures match"
        )
        .font(.system(size: 13))
        .foregroundStyle(.secondary)
        Spacer()
      }.frame(maxWidth: .infinity)
    } else {
      ScrollView {
        VStack(spacing: 0) {
          PostedListView(
            captures: displayedPostedCaptures,
            onOpenPostedURL: { openPostedURL(for: $0) },
            onRestore: { restoreCaptureToQueue($0) },
            onDelete: { deleteCapture($0) }
          )
        }
      }
    }
  }

  private func captureList(_ captures: [Capture]) -> some View {
    let map = urgencyBySubredditId
    return ForEach(captures, id: \.id) { capture in
      CaptureCardView(
        capture: capture,
        urgency: capture.subreddits.compactMap { map[$0.id] }.max() ?? .none,
        nextWindowText: PopoverTimingPresentation.nextWindowText(
          for: capture,
          windows: timingEngine.upcomingWindows
        ),
        onTap: { openCaptureForEditing(capture) },
        onOpenHandoff: { openPostHandoff(for: capture) },
        onCopyText: { copyPostText(for: capture) },
        onOpenSubmit: { openRedditSubmitPage(for: capture) },
        onMarkPosted: { markCaptureAsPosted(capture) },
        onDelete: { deleteCapture(capture) }
      )
      if capture.id != captures.last?.id { Divider().padding(.horizontal, 16) }
    }
  }

  // MARK: - Header / Footer / Empty states

  private var header: some View {
    PopoverHeaderView(
      selectedWorkspace: $selectedWorkspace,
      onOpenPreferences: { openPreferences() },
      onNewCapture: openNewCapture
    )
  }

  private var searchBar: some View {
    PopoverSearchBarView(searchText: $searchText)
  }

  private var filterBar: some View {
    PopoverFilterBarView(
      subredditName: subreddits.first(where: { $0.id == filterSubredditId })?.name,
      onClear: {
        withAnimation(.easeInOut(duration: 0.15)) { filterSubredditId = nil }
      }
    )
  }

  private var footer: some View {
    let text = PopoverTimingPresentation.footerText(
      showPosted: selectedWorkspace == .posted,
      queuedCaptureCount: queuedCaptures.count,
      postedCaptureCount: postedCaptures.count,
      upcomingEventCount: timingEngine.upcomingWindows.count
    )
    return PopoverFooterView(text: text)
  }

  // Actions live in PopoverContentActions.swift.
}
