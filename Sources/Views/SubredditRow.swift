import SwiftUI
import SwiftData

// MARK: - SubredditRow (isolates re-evaluation scope)

struct SubredditRow: View {
    @Bindable var sub: Subreddit
    let isExpanded: Bool
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Button(action: onToggle) {
                HStack {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(StickerColors.reddit)
                            .frame(width: 8, height: 8)
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10))
                            .foregroundStyle(isExpanded ? StickerColors.gold : StickerColors.textSecondary)
                        Text(sub.name)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(StickerColors.textPrimary)
                    }
                    Spacer()
                    if isExpanded {
                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                                .foregroundStyle(StickerColors.reddit)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text(peakDaysSummary)
                            .foregroundStyle(StickerColors.textSecondary)
                            .stickerBadge(color: StickerColors.border)
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(10)

            // Expanded detail
            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    StickerDivider()

                    stickerSectionLabel("Peak Days", size: 9)
                    peakDayChips

                    stickerSectionLabel("Peak Hours (UTC)", size: 9)
                    peakHourChips

                    HStack {
                        Spacer()
                        Button(action: resetDefaults) {
                            Text("Reset to defaults")
                                .font(.system(size: 9))
                                .foregroundStyle(StickerColors.textSecondary)
                                .underline()
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
        }
        .stickerCard(borderColor: isExpanded ? StickerColors.gold : StickerColors.border)
    }

    // MARK: - Peak Day Chips

    private static let allDays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    private static let dayKeys = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]

    private var peakDayChips: some View {
        HStack(spacing: 4) {
            ForEach(Array(zip(Self.allDays, Self.dayKeys)), id: \.0) { display, key in
                let isOn = sub.peakDaysOverride?.contains(key) ?? false
                Button(action: { toggleDay(key) }) {
                    Text(display)
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(isOn ? StickerColors.gold.opacity(0.2) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isOn ? StickerColors.gold : StickerColors.border, lineWidth: 2)
                        )
                        .foregroundStyle(isOn ? StickerColors.gold : StickerColors.textSecondary)
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
        // No save here — saved on collapse or navigation away
    }

    // MARK: - Peak Hour Chips

    private static let displayHours = [0, 2, 4, 6, 8, 10, 12, 14, 15, 16, 17, 18, 20, 22]

    private var peakHourChips: some View {
        let columns = [GridItem(.adaptive(minimum: 30), spacing: 3)]
        return LazyVGrid(columns: columns, spacing: 3) {
            ForEach(Self.displayHours, id: \.self) { hour in
                let isOn = sub.peakHoursUtcOverride?.contains(hour) ?? false
                Button(action: { toggleHour(hour) }) {
                    Text("\(hour)")
                        .font(.system(size: 9, weight: .bold))
                        .frame(minWidth: 24)
                        .padding(.vertical, 3)
                        .background(isOn ? StickerColors.green.opacity(0.2) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(isOn ? StickerColors.green : StickerColors.border, lineWidth: 2)
                        )
                        .foregroundStyle(isOn ? StickerColors.green : StickerColors.textSecondary)
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
        // No save here — saved on collapse or navigation away
    }

    // MARK: - Helpers

    private var peakDaysSummary: String {
        guard let days = sub.peakDaysOverride, !days.isEmpty else { return "defaults" }
        return days.map { $0.prefix(3).capitalized }.joined(separator: " ")
    }

    private func resetDefaults() {
        sub.peakDaysOverride = nil
        sub.peakHoursUtcOverride = nil
        // No save here — saved on collapse or navigation away
    }
}

// MARK: - Drag & Drop

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
