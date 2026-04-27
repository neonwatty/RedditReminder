import SwiftUI
import SwiftData

struct PopoverContentView: View {
    let menuBarController: MenuBarController
    let notificationService: NotificationService
    let onCaptureChanged: @MainActor () -> Void

    @Query(sort: \Capture.createdAt, order: .reverse) private var captures: [Capture]
    @Query private var allEvents: [SubredditEvent]
    @Query(sort: \Subreddit.sortOrder) private var subreddits: [Subreddit]

    @Environment(\.modelContext) private var modelContext

    @State private var timingEngine = TimingEngine()
    @State private var filterSubredditId: UUID?

    private var activeEvents: [SubredditEvent] { allEvents.filter(\.isActive) }
    private var queuedCaptures: [Capture] { captures.filter { $0.status == .queued } }

    private var displayedCaptures: [Capture] {
        guard let filterId = filterSubredditId else { return queuedCaptures }
        return queuedCaptures.filter { $0.subreddits.contains(where: { $0.id == filterId }) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if filterSubredditId != nil {
                filterBar
            }

            if displayedCaptures.isEmpty && timingEngine.upcomingWindows.isEmpty && filterSubredditId == nil {
                emptyState
            } else if displayedCaptures.isEmpty && filterSubredditId != nil {
                filteredEmptyState
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        EventBannerView(
                            upcomingWindows: timingEngine.upcomingWindows,
                            onTap: { window in
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    if filterSubredditId == window.event.subreddit?.id {
                                        filterSubredditId = nil
                                    } else {
                                        filterSubredditId = window.event.subreddit?.id
                                    }
                                }
                            }
                        )

                        ForEach(displayedCaptures, id: \.id) { capture in
                            CaptureCardView(
                                capture: capture,
                                urgency: urgencyForCapture(capture),
                                onTap: { openCaptureForEditing(capture) }
                            )

                            if capture.id != displayedCaptures.last?.id {
                                Divider()
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                }
            }

            footer
        }
        .frame(width: 350)
        .frame(maxHeight: maxPopoverHeight)
        .onAppear {
            timingEngine.refresh(events: activeEvents, captures: captures)
            menuBarController.onNewCapture = { [self] in openNewCapture() }
            menuBarController.onOpenPreferences = { [self] in openPreferences() }
        }
        .onChange(of: captures.count) {
            timingEngine.refresh(events: activeEvents, captures: captures)
            onCaptureChanged()
        }
    }

    private var maxPopoverHeight: CGFloat {
        let screenHeight = NSScreen.main?.visibleFrame.height ?? 800
        return screenHeight * 0.85
    }

    // MARK: - Urgency per capture

    private func urgencyForCapture(_ capture: Capture) -> UrgencyLevel {
        let captureSubIds = Set(capture.subreddits.map(\.id))
        var highest: UrgencyLevel = .none
        for window in timingEngine.upcomingWindows {
            if let subId = window.event.subreddit?.id, captureSubIds.contains(subId) {
                highest = max(highest, window.urgency)
            }
        }
        return highest
    }

    // MARK: - Header / Footer / Empty states

    private var header: some View {
        HStack {
            Text("RedditReminder")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer()

            Button(action: openPreferences) {
                Image(systemName: "gearshape")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Button(action: openNewCapture) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(AppColors.redditOrange)
            }
            .buttonStyle(.plain)
            .padding(.leading, 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private var filterBar: some View {
        HStack {
            if let sub = subreddits.first(where: { $0.id == filterSubredditId }) {
                Text("Filtered: \(sub.name)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AppColors.redditOrange)
            }
            Spacer()
            Button("Show all") {
                withAnimation(.easeInOut(duration: 0.15)) {
                    filterSubredditId = nil
                }
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.secondary)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(AppColors.redditOrange.opacity(0.06))
        .overlay(alignment: .bottom) { Divider() }
    }

    private var footer: some View {
        let eventCount = timingEngine.upcomingWindows.count
        let captureCount = queuedCaptures.count

        return VStack(spacing: 0) {
            Divider()
            Text("\(captureCount) capture\(captureCount == 1 ? "" : "s") · \(eventCount) event\(eventCount == 1 ? "" : "s") upcoming")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .padding(.vertical, 8)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Text("No captures yet")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Button("+ New Capture", action: openNewCapture)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppColors.redditOrange)
                .buttonStyle(.plain)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var filteredEmptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Text("No captures for this subreddit")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    private func openNewCapture() {
        let formView = CaptureWindowView(
            mode: .create,
            onSave: { result in
                saveCapture(result)
                menuBarController.closeCaptureWindow()
            },
            onCancel: {
                menuBarController.closeCaptureWindow()
            }
        )
        .modelContainer(modelContext.container)

        menuBarController.showCaptureWindow(title: "New Capture", content: formView)
    }

    private func openCaptureForEditing(_ capture: Capture) {
        let formView = CaptureWindowView(
            mode: .edit(capture),
            onSave: { result in
                updateCapture(capture, with: result)
                menuBarController.closeCaptureWindow()
            },
            onCancel: {
                menuBarController.closeCaptureWindow()
            }
        )
        .modelContainer(modelContext.container)

        menuBarController.showCaptureWindow(title: "Edit Capture", content: formView)
    }

    private func openPreferences() {
        let prefsView = PreferencesView(notificationService: notificationService)
            .modelContainer(modelContext.container)

        menuBarController.showPreferencesWindow(content: prefsView)
    }

    private func saveCapture(_ result: CaptureFormResult) {
        let capture = Capture(
            text: result.text,
            notes: result.notes,
            links: result.links,
            mediaRefs: result.mediaURLs.map(\.lastPathComponent),
            project: result.project,
            subreddits: result.subreddits
        )
        modelContext.insert(capture)
        try? modelContext.save()
    }

    private func updateCapture(_ capture: Capture, with result: CaptureFormResult) {
        capture.text = result.text
        capture.notes = result.notes
        capture.links = result.links
        capture.mediaRefs = result.mediaURLs.map(\.lastPathComponent)
        capture.project = result.project
        capture.subreddits = result.subreddits
        try? modelContext.save()
    }
}
