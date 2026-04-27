import SwiftUI

struct CalendarTimelineView: View {
    let windows: [TimingEngine.UpcomingWindow]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(groupedByDate.enumerated()), id: \.offset) { _, group in
                timelineItem(date: group.date, windows: group.windows)
            }
        }
        .padding(.leading, 7)
    }

    private var groupedByDate: [(date: Date, windows: [TimingEngine.UpcomingWindow])] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: windows) { window in
            cal.startOfDay(for: window.eventDate)
        }
        return grouped.sorted { $0.key < $1.key }.map { (date: $0.key, windows: $0.value) }
    }

    private func timelineItem(date: Date, windows: [TimingEngine.UpcomingWindow]) -> some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(spacing: 0) {
                Circle()
                    .fill(dotColor(for: windows))
                    .frame(width: 10, height: 10)
                Rectangle()
                    .fill(StickerColors.border)
                    .frame(width: 2)
            }
            .frame(width: 16)

            VStack(alignment: .leading, spacing: 6) {
                Text(dateLabel(date))
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1)
                    .textCase(.uppercase)
                    .foregroundStyle(dotColor(for: windows))

                ForEach(Array(windows.enumerated()), id: \.offset) { _, window in
                    EventCardView(window: window)
                }
            }
            .padding(.leading, 10)
            .padding(.bottom, 16)
        }
    }

    private func dotColor(for windows: [TimingEngine.UpcomingWindow]) -> Color {
        (windows.map(\.urgency).max() ?? .none).color
    }

    private func dateLabel(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            return "Today · \(shortDate(date))"
        } else if cal.isDateInTomorrow(date) {
            return "Tomorrow · \(shortDate(date))"
        } else {
            return shortDate(date)
        }
    }

    private func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE MMM d"
        return f.string(from: date)
    }
}
