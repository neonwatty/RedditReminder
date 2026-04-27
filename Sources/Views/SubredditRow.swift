import SwiftUI
import SwiftData

struct SubredditRow: View {
    @Bindable var sub: Subreddit
    let isExpanded: Bool
    let onToggle: () -> Void
    let onDelete: () -> Void

    private static let redditOrange = Color(red: 1.0, green: 0.27, blue: 0.0)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10))
                            .foregroundStyle(isExpanded ? Self.redditOrange : .secondary)
                        Text(sub.name)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
                    Spacer()
                    if isExpanded {
                        Button("Remove", action: onDelete)
                            .font(.system(size: 11))
                            .foregroundStyle(.red)
                            .buttonStyle(.plain)
                    } else {
                        Text(peakDaysSummary)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(10)

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    Divider()

                    Text("PEAK DAYS")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                        .tracking(0.3)
                    peakDayChips

                    Text("PEAK HOURS (UTC)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                        .tracking(0.3)
                    peakHourChips

                    HStack {
                        Spacer()
                        Button("Reset to defaults", action: resetDefaults)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .underline()
                            .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
        }
        .background(.quaternary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.separator, lineWidth: 0.5)
        )
    }

    private static let allDays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    private static let dayKeys = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]

    private var peakDayChips: some View {
        HStack(spacing: 4) {
            ForEach(Array(zip(Self.allDays, Self.dayKeys)), id: \.0) { display, key in
                let isOn = sub.peakDaysOverride?.contains(key) ?? false
                Button(action: { toggleDay(key) }) {
                    Text(display)
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(isOn ? Self.redditOrange.opacity(0.12) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(isOn ? Self.redditOrange : Color(NSColor.separatorColor), lineWidth: 0.5)
                        )
                        .foregroundStyle(isOn ? Self.redditOrange : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func toggleDay(_ day: String) {
        var days = sub.peakDaysOverride ?? []
        if days.contains(day) {
            days.removeAll { $0 == day }
        } else {
            days.append(day)
        }
        sub.peakDaysOverride = days.isEmpty ? nil : days
    }

    private static let displayHours = [0, 2, 4, 6, 8, 10, 12, 14, 15, 16, 17, 18, 20, 22]

    private var peakHourChips: some View {
        let columns = [GridItem(.adaptive(minimum: 30), spacing: 3)]
        let hours = Self.displayHours
        return LazyVGrid(columns: columns, spacing: 3) {
            ForEach(hours, id: \.self) { hour in
                let isOn = sub.peakHoursUtcOverride?.contains(hour) ?? false
                Button(action: { toggleHour(hour) }) {
                    Text("\(hour)")
                        .font(.system(size: 9, weight: .medium))
                        .frame(minWidth: 24)
                        .padding(.vertical, 3)
                        .background(isOn ? Color.green.opacity(0.12) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(isOn ? Color.green : Color(NSColor.separatorColor), lineWidth: 0.5)
                        )
                        .foregroundStyle(isOn ? .green : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func toggleHour(_ hour: Int) {
        var hours = sub.peakHoursUtcOverride ?? []
        if hours.contains(hour) {
            hours.removeAll { $0 == hour }
        } else {
            hours.append(hour)
            hours.sort()
        }
        sub.peakHoursUtcOverride = hours.isEmpty ? nil : hours
    }

    private var peakDaysSummary: String {
        guard let days = sub.peakDaysOverride, !days.isEmpty else { return "defaults" }
        return days.map { $0.prefix(3).capitalized }.joined(separator: " ")
    }

    private func resetDefaults() {
        sub.peakDaysOverride = nil
        sub.peakHoursUtcOverride = nil
    }
}

struct SubredditDropDelegate: DropDelegate {
    let target: Subreddit
    @Binding var dragging: Subreddit?
    let subreddits: [Subreddit]
    let modelContext: ModelContext

    func performDrop(info: DropInfo) -> Bool {
        dragging = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let source = dragging, source.id != target.id else { return }
        guard let fromIndex = subreddits.firstIndex(where: { $0.id == source.id }),
              let toIndex = subreddits.firstIndex(where: { $0.id == target.id }) else { return }

        var reordered = subreddits
        let item = reordered.remove(at: fromIndex)
        reordered.insert(item, at: toIndex)

        for (i, sub) in reordered.enumerated() {
            sub.sortOrder = i
        }
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            NSLog("RedditReminder: failed to save subreddit reorder: \(error)")
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}
