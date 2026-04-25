import SwiftUI

struct BrowseView: View {
    let captures: [Capture]
    let upcomingWindows: [TimingEngine.UpcomingWindow]
    let onNewCapture: () -> Void
    var onMarkPosted: ((Capture) -> Void)? = nil

    @State private var activeTab: Tab = .queue

    enum Tab { case queue, calendar }
    @State private var calendarMode: CalendarMode = .timeline
    enum CalendarMode { case timeline, month }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                tabButton("Queue", tab: .queue)
                tabButton("Calendar", tab: .calendar)
            }
            .overlay(alignment: .bottom) { Divider() }

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if activeTab == .queue {
                        queueContent
                    } else {
                        calendarContent
                    }
                }
                .padding(10)
            }

            Button(action: onNewCapture) {
                Text("+ New Capture")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(nsColor: AppColors.reddit))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .padding(10)
        }
    }

    @ViewBuilder
    private var queueContent: some View {
        let queued = captures.filter { $0.status == .queued }
        let posted = captures.filter { $0.status == .posted }

        if !queued.isEmpty {
            sectionLabel("Queued · \(queued.count)")
            ForEach(queued, id: \.id) { capture in
                CaptureCardView(capture: capture, compact: false) {
                    onMarkPosted?(capture)
                }
            }
        }

        if !posted.isEmpty {
            sectionLabel("Recently Posted")
            ForEach(posted.prefix(5), id: \.id) { capture in
                CaptureCardView(capture: capture, compact: false)
                    .opacity(0.5)
            }
        }
    }

    @ViewBuilder
    private var calendarContent: some View {
        HStack {
            Picker("", selection: $calendarMode) {
                Text("Month").tag(CalendarMode.month)
                Text("Timeline").tag(CalendarMode.timeline)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 200)
        }

        if calendarMode == .timeline {
            CalendarTimelineView(windows: upcomingWindows)
        } else {
            CalendarMonthView(windows: upcomingWindows)
        }
    }

    private func tabButton(_ title: String, tab: Tab) -> some View {
        Button(action: { activeTab = tab }) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(activeTab == tab ? Color(nsColor: AppColors.reddit) : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .overlay(alignment: .bottom) {
                    if activeTab == tab {
                        Rectangle()
                            .fill(Color(nsColor: AppColors.reddit))
                            .frame(height: 2)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .medium))
            .tracking(1.5)
            .textCase(.uppercase)
            .foregroundStyle(.tertiary)
    }
}
