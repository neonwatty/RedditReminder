import SwiftUI

struct CalendarMonthView: View {
    let windows: [TimingEngine.UpcomingWindow]
    @State private var displayMonth = Date()
    @State private var selectedDay: Date?

    private let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]
    private let cal = Calendar.current

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button(action: previousMonth) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11))
                        .foregroundStyle(StickerColors.textSecondary)
                }
                .buttonStyle(.plain)

                Spacer()
                Text(monthTitle)
                    .font(.system(size: 13, weight: .bold))
                Spacer()

                Button(action: nextMonth) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11))
                        .foregroundStyle(StickerColors.textSecondary)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 0) {
                ForEach(dayLabels, id: \.self) { label in
                    Text(label)
                        .font(.system(size: 9))
                        .foregroundStyle(StickerColors.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 2) {
                ForEach(daysInMonth, id: \.self) { day in
                    if let day {
                        dayCell(day)
                    } else {
                        Color.clear.aspectRatio(1, contentMode: .fit)
                    }
                }
            }

            if let selected = selectedDay {
                let dayWindows = windowsFor(day: selected)
                if !dayWindows.isEmpty {
                    StickerDivider()
                        .padding(.vertical, 4)
                    Text(dayDetailTitle(selected))
                        .font(.system(size: 9, weight: .medium))
                        .tracking(1)
                        .textCase(.uppercase)
                        .foregroundStyle(StickerColors.textSecondary)

                    ForEach(Array(dayWindows.enumerated()), id: \.offset) { _, window in
                        EventCardView(window: window)
                    }
                }
            }
        }
    }

    private func dayCell(_ date: Date) -> some View {
        let dots = windowsFor(day: date)
        let isSelected = selectedDay.map { cal.isDate($0, inSameDayAs: date) } ?? false
        let isToday = cal.isDateInToday(date)

        return Button(action: { selectedDay = date }) {
            VStack(spacing: 2) {
                Text("\(cal.component(.day, from: date))")
                    .font(.system(size: 10))
                    .foregroundStyle(isToday ? StickerColors.reddit : .primary)

                if !dots.isEmpty {
                    HStack(spacing: 1) {
                        ForEach(Array(dots.prefix(3).enumerated()), id: \.offset) { _, w in
                            Circle()
                                .fill(w.urgency.color)
                                .frame(width: 4, height: 4)
                        }
                    }
                } else {
                    Color.clear.frame(height: 4)
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(isSelected ? StickerColors.card : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isSelected ? StickerColors.border : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var monthTitle: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: displayMonth)
    }

    private var daysInMonth: [Date?] {
        let range = cal.range(of: .day, in: .month, for: displayMonth)!
        let firstDay = cal.date(from: cal.dateComponents([.year, .month], from: displayMonth))!
        var weekday = cal.component(.weekday, from: firstDay) - 2
        if weekday < 0 { weekday += 7 }

        var days: [Date?] = Array(repeating: nil, count: weekday)
        for day in range {
            var comps = cal.dateComponents([.year, .month], from: displayMonth)
            comps.day = day
            days.append(cal.date(from: comps))
        }
        return days
    }

    private func windowsFor(day: Date) -> [TimingEngine.UpcomingWindow] {
        windows.filter { cal.isDate($0.fireDate, inSameDayAs: day) }
    }

    private func previousMonth() {
        displayMonth = cal.date(byAdding: .month, value: -1, to: displayMonth) ?? displayMonth
    }

    private func nextMonth() {
        displayMonth = cal.date(byAdding: .month, value: 1, to: displayMonth) ?? displayMonth
    }

    private func dayDetailTitle(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE MMM d"
        let count = windowsFor(day: date).count
        return "\(f.string(from: date)) — \(count) event\(count == 1 ? "" : "s")"
    }

}
