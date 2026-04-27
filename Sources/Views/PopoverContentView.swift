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

    private var activeEvents: [SubredditEvent] { allEvents.filter(\.isActive) }
    private var queuedCaptures: [Capture] { captures.filter { $0.status == .queued } }

    var body: some View {
        VStack(spacing: 0) {
            header

            if queuedCaptures.isEmpty && timingEngine.upcomingWindows.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        EventBannerView(
                            upcomingWindows: timingEngine.upcomingWindows
                        )

                        ForEach(queuedCaptures, id: \.id) { capture in
                            CaptureCardView(capture: capture, onTap: {
                                openCaptureForEditing(capture)
                            })

                            if capture.id != queuedCaptures.last?.id {
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
        .onAppear {
            timingEngine.refresh(events: activeEvents, captures: captures)
        }
        .onChange(of: captures.count) {
            timingEngine.refresh(events: activeEvents, captures: captures)
            onCaptureChanged()
        }
    }

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
                    .foregroundStyle(Color(red: 1.0, green: 0.27, blue: 0.0))
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
                .foregroundStyle(Color(red: 1.0, green: 0.27, blue: 0.0))
                .buttonStyle(.plain)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

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

        menuBarController.showCaptureWindow(content: formView)
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

        menuBarController.showCaptureWindow(content: formView)
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
