import SwiftUI

struct SidebarContainer: View {
    @Bindable var panelController: PanelController
    var timingEngine: TimingEngine = TimingEngine()
    var captures: [Capture] = []

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
                        onNewCapture: { panelController.setState(.capture) }
                    )
                case .capture:
                    CaptureFormView(
                        projects: [],
                        subreddits: [],
                        onSave: { _, _, _, _, _ in
                            panelController.setState(.browse)
                        },
                        onCancel: { panelController.setState(.browse) }
                    )
                }
            }
        }
    }

    private var header: some View {
        HStack {
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
