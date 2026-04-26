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
            .overlay(alignment: .bottom) {
                StickerDivider()
            }

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
                    .stickerButton(bgColor: StickerColors.reddit)
            }
            .buttonStyle(.plain)
            .padding(10)
        }
    }

    @ViewBuilder
    private var queueContent: some View {
        let (queued, posted) = partitionCaptures()

        if !queued.isEmpty {
            stickerSectionLabel("Queued · \(queued.count)")
            ForEach(queued, id: \.id) { capture in
                CaptureCardView(capture: capture, compact: false) {
                    onMarkPosted?(capture)
                }
            }
        }

        if !posted.isEmpty {
            stickerSectionLabel("Recently Posted")
            ForEach(posted.prefix(5), id: \.id) { capture in
                CaptureCardView(capture: capture, compact: false)
                    .opacity(0.5)
            }
        }
    }

    private func partitionCaptures() -> (queued: [Capture], posted: [Capture]) {
        var queued: [Capture] = []
        var posted: [Capture] = []
        for capture in captures {
            switch capture.status {
            case .queued: queued.append(capture)
            case .posted: posted.append(capture)
            }
        }
        return (queued, posted)
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
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(activeTab == tab ? StickerColors.gold : StickerColors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .overlay(alignment: .bottom) {
                    if activeTab == tab {
                        Rectangle()
                            .fill(StickerColors.gold)
                            .frame(height: 2)
                    }
                }
        }
        .buttonStyle(.plain)
    }

}
