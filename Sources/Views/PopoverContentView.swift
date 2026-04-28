import SwiftUI
import SwiftData

struct PopoverContentView: View {
    let menuBarController: MenuBarController
    let notificationService: NotificationService
    let heuristicsStore: HeuristicsStore
    let onCaptureChanged: @MainActor () -> Void
    let mediaStore = MediaStore()

    @Query(sort: \Capture.createdAt, order: .reverse) private var captures: [Capture]
    @Query private var allEvents: [SubredditEvent]
    @Query(sort: \Subreddit.sortOrder) private var subreddits: [Subreddit]
    @Environment(\.modelContext) var modelContext

    @State private var timingEngine = TimingEngine()
    @State private var filterSubredditId: UUID?
    @State private var searchText: String = ""
    @State var toastMessage: String?
    @State var toastTask: Task<Void, Never>?
    @State private var showPosted: Bool = false

    private var activeEvents: [SubredditEvent] { PopoverTimingPresentation.activeEvents(from: allEvents) }
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
            header
            if !captures.isEmpty { searchBar }
            if showPosted { postedContent } else { queuedContent }
            footer
        }
        .overlay(alignment: .top) {
            if let message = toastMessage {
                PopoverToastView(message: message)
            }
        }
        .background(AppColors.popoverBg)
        .frame(width: 350).frame(maxHeight: (NSScreen.main?.visibleFrame.height ?? 800) * 0.85)
        .onAppear {
            refreshTiming()
            menuBarController.onNewCapture = { [self] in openNewCapture() }
            menuBarController.onOpenPreferences = { [self] in openPreferences() }
        }
        .onChange(of: captureTimingSignature) {
            refreshTiming()
        }
        .onChange(of: eventTimingSignature) {
            refreshTiming()
        }
        .onChange(of: subredditTimingSignature) {
            refreshTiming()
        }
    }

    private var captureTimingSignature: [String] {
        PopoverTimingPresentation.captureTimingSignature(from: captures)
    }

    private var eventTimingSignature: [String] {
        PopoverTimingPresentation.eventTimingSignature(from: allEvents)
    }

    private var subredditTimingSignature: [String] {
        PopoverTimingPresentation.subredditTimingSignature(from: subreddits)
    }

    private func refreshTiming() {
        timingEngine.refresh(events: activeEvents, captures: captures)
    }

    // MARK: - Urgency

    private var urgencyBySubredditId: [UUID: UrgencyLevel] {
        PopoverTimingPresentation.urgencyBySubredditId(from: timingEngine.upcomingWindows)
    }

    // MARK: - Content

    @ViewBuilder
    private var queuedContent: some View {
        if filterSubredditId != nil { filterBar }
        if displayedCaptures.isEmpty && timingEngine.upcomingWindows.isEmpty && filterSubredditId == nil {
            emptyState
        } else if displayedCaptures.isEmpty && filterSubredditId != nil {
            filteredEmptyState
        } else {
            ScrollView {
                VStack(spacing: 0) {
                    EventBannerView(upcomingWindows: timingEngine.upcomingWindows, onTap: { window in
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
                Text(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "No posted captures yet" : "No posted captures match")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Spacer()
            }.frame(maxWidth: .infinity)
        } else {
            ScrollView {
                VStack(spacing: 0) {
                    PostedListView(
                        captures: displayedPostedCaptures,
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
                onTap: { openCaptureForEditing(capture) },
                onMarkPosted: { markCaptureAsPosted(capture) },
                onDelete: { deleteCapture(capture) }
            )
            if capture.id != captures.last?.id { Divider().padding(.horizontal, 16) }
        }
    }

    // MARK: - Header / Footer / Empty states

    private var header: some View {
        PopoverHeaderView(
            showPosted: $showPosted,
            onOpenPreferences: openPreferences,
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
            showPosted: showPosted,
            queuedCaptureCount: queuedCaptures.count,
            postedCaptureCount: postedCaptures.count,
            upcomingEventCount: timingEngine.upcomingWindows.count
        )
        return PopoverFooterView(text: text)
    }

    // Actions live in PopoverContentActions.swift.
}
