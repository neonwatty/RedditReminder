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
                Text(message).font(.system(size: 11, weight: .medium)).foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(AppColors.redditOrange.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.top, 48)
                    .transition(.move(edge: .top).combined(with: .opacity))
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
        HStack {
            Text("RedditReminder").font(.system(size: 13, weight: .semibold)).foregroundStyle(.primary)
            Spacer()
            HStack(spacing: 2) {
                toggleButton("Queue", active: !showPosted) { showPosted = false }
                toggleButton("Posted", active: showPosted) { showPosted = true }
            }
            Spacer()
            Button(action: openPreferences) {
                Image(systemName: "gearshape").font(.system(size: 11)).foregroundStyle(.secondary)
            }.buttonStyle(.plain)
            Button(action: openNewCapture) {
                Image(systemName: "plus").font(.system(size: 14, weight: .light))
                    .foregroundStyle(AppColors.redditOrange)
            }.buttonStyle(.plain).padding(.leading, 8)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .overlay(alignment: .bottom) { Divider() }
    }

    private func toggleButton(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10, weight: active ? .semibold : .medium))
                .foregroundStyle(active ? AppColors.redditOrange : .secondary)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(active ? AppColors.redditOrange.opacity(0.1) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }.buttonStyle(.plain)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            TextField("Search captures", text: $searchText)
                .font(.system(size: 11))
                .textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.quaternary.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) { Divider() }
    }

    private var filterBar: some View {
        HStack {
            if let sub = subreddits.first(where: { $0.id == filterSubredditId }) {
                Text("Filtered: \(sub.name)").font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AppColors.redditOrange)
            }
            Spacer()
            Button("Show all") { withAnimation(.easeInOut(duration: 0.15)) { filterSubredditId = nil } }
                .font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary).buttonStyle(.plain)
        }
        .padding(.horizontal, 16).padding(.vertical, 6)
        .background(AppColors.redditOrange.opacity(0.06))
        .overlay(alignment: .bottom) { Divider() }
    }

    private var footer: some View {
        let text = PopoverTimingPresentation.footerText(
            showPosted: showPosted,
            queuedCaptureCount: queuedCaptures.count,
            postedCaptureCount: postedCaptures.count,
            upcomingEventCount: timingEngine.upcomingWindows.count
        )
        return VStack(spacing: 0) {
            Divider()
            Text(text).font(.system(size: 10)).foregroundStyle(.secondary).padding(.vertical, 8)
        }
    }

    // Actions live in PopoverContentActions.swift.
}
