import SwiftUI
import SwiftData

struct SidebarContainer: View {
    @Bindable var panelController: PanelController
    @State private var timingEngine = TimingEngine()
    @State private var titleTapCount = 0
    @State private var lastTapTime = Date.distantPast
    @State private var showDevMenu = false

    @Query(sort: \Capture.createdAt, order: .reverse) private var captures: [Capture]
    @Query(sort: \Project.name) private var projects: [Project]
    @Query(sort: \Subreddit.name) private var subreddits: [Subreddit]
    @Query private var allEvents: [SubredditEvent]

    @Environment(\.modelContext) private var modelContext

    private var activeEvents: [SubredditEvent] { allEvents.filter(\.isActive) }

    var body: some View {
        ZStack {
            StickerColors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if panelController.state != .strip {
                    header
                }

                switch panelController.state {
                case .strip:
                    StripView(
                        queueCount: captures.filter { $0.status == .queued }.count,
                        hasUrgentEvent: timingEngine.upcomingWindows.contains { $0.urgency >= .high },
                        onTap: { panelController.setState(.glance) }
                    )
                case .glance:
                    GlanceView(
                        upcomingWindows: timingEngine.upcomingWindows,
                        captures: captures,
                        onCaptureCardTap: { panelController.setState(.browse) },
                        onNewCapture: { panelController.setState(.capture) }
                    )
                case .browse:
                    BrowseView(
                        captures: captures,
                        upcomingWindows: timingEngine.upcomingWindows,
                        onNewCapture: { panelController.setState(.capture) },
                        onMarkPosted: { capture in
                            capture.markAsPosted()
                            do {
                                try modelContext.save()
                            } catch {
                                modelContext.rollback()
                                NSLog("RedditReminder: failed to save posted status: \(error)")
                            }
                        }
                    )
                case .capture:
                    CaptureFormView(
                        projects: projects,
                        subreddits: subreddits,
                        onSave: { text, notes, optionalProject, subs, mediaURLs in
                            let capture = Capture(
                                text: text,
                                notes: notes,
                                mediaRefs: mediaURLs.map(\.lastPathComponent),
                                project: optionalProject,
                                subreddits: subs
                            )
                            modelContext.insert(capture)
                            do {
                                try modelContext.save()
                                panelController.setState(.browse)
                            } catch {
                                modelContext.rollback()
                                NSLog("RedditReminder: failed to save capture: \(error)")
                            }
                        },
                        onCancel: { panelController.setState(.browse) }
                    )
                case .channels:
                    Text("Channels") // placeholder — replaced in Task 9
                case .settings:
                    SettingsView(panelController: panelController)
                }
            }

            if showDevMenu {
                devMenuOverlay
            }
        }
        .onAppear {
            timingEngine.refresh(events: activeEvents, captures: captures)
        }
        .onChange(of: captures.count) {
            timingEngine.refresh(events: activeEvents, captures: captures)
        }
    }

    private var devMenuOverlay: some View {
        VStack(spacing: 8) {
            Text("DEVELOPER")
                .font(.system(size: 9, weight: .heavy))
                .tracking(2)
                .foregroundStyle(StickerColors.textSecondary)

            Button(action: {
                QAFixtures.seed(context: modelContext)
                showDevMenu = false
            }) {
                Text("Seed QA Data")
                    .stickerButton(bgColor: Color(nsColor: AppColors.green))
            }
            .buttonStyle(.plain)

            Button(action: {
                QAFixtures.clearAll(context: modelContext)
                showDevMenu = false
            }) {
                Text("Clear All Data")
                    .stickerButton(bgColor: StickerColors.reddit)
            }
            .buttonStyle(.plain)

            Button(action: { showDevMenu = false }) {
                Text("Dismiss")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(StickerColors.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .stickerCard()
        .padding(.horizontal, 20)
        .padding(.top, 60)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var header: some View {
        HStack {
            Button(action: { panelController.goToSettings() }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(StickerColors.textSecondary)
            }
            .buttonStyle(.plain)

            Text("RedditReminder")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(StickerColors.gold)
                .onTapGesture {
                    let now = Date()
                    if now.timeIntervalSince(lastTapTime) > 2 {
                        titleTapCount = 1
                    } else {
                        titleTapCount += 1
                    }
                    lastTapTime = now
                    if titleTapCount >= 5 {
                        showDevMenu = true
                        titleTapCount = 0
                    }
                }
            Spacer()
            Button(action: { panelController.stepDown() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(StickerColors.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            StickerDivider()
        }
    }
}
