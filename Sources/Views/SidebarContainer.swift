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
            Color(red: 0.08, green: 0.08, blue: 0.16)
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
                            try? modelContext.save()
                        }
                    )
                case .capture:
                    CaptureFormView(
                        projects: projects,
                        subreddits: subreddits,
                        onSave: { text, notes, project, subs, mediaURLs in
                            let capture = Capture(
                                text: text,
                                notes: notes,
                                mediaRefs: mediaURLs.map(\.lastPathComponent),
                                project: project,
                                subreddits: subs
                            )
                            modelContext.insert(capture)
                            try? modelContext.save()
                            panelController.setState(.browse)
                        },
                        onCancel: { panelController.setState(.browse) }
                    )
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
                .font(.system(size: 9, weight: .bold))
                .tracking(2)
                .foregroundStyle(.tertiary)

            Button(action: {
                QAFixtures.seed(context: modelContext)
                showDevMenu = false
            }) {
                Text("Seed QA Data")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color(nsColor: AppColors.green))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)

            Button(action: {
                QAFixtures.clearAll(context: modelContext)
                showDevMenu = false
            }) {
                Text("Clear All Data")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color(nsColor: AppColors.reddit))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)

            Button(action: { showDevMenu = false }) {
                Text("Dismiss")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color(red: 0.12, green: 0.12, blue: 0.20))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 20)
        .padding(.top, 60)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var header: some View {
        HStack {
            Button(action: { panelController.goToSettings() }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Text("RedditReminder")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color(nsColor: AppColors.reddit))
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
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}
