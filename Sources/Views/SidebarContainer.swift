import SwiftUI
import SwiftData

struct SidebarContainer: View {
    @Bindable var panelController: PanelController
    @State private var timingEngine = TimingEngine()

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
        }
        .onAppear {
            timingEngine.refresh(events: activeEvents, captures: captures)
        }
        .onChange(of: captures.count) {
            timingEngine.refresh(events: activeEvents, captures: captures)
        }
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
