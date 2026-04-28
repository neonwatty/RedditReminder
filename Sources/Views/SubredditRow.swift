import SwiftUI
import SwiftData

struct SubredditRow: View {
    @Bindable var sub: Subreddit
    let peakInfo: PeakInfo?
    let isExpanded: Bool
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10))
                            .foregroundStyle(isExpanded ? AppColors.redditOrange : .secondary)
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
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(peakDaysSummary)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                            Text(eventSourceSummary.compactLabel)
                                .font(.system(size: 9))
                                .foregroundStyle(eventSourceSummary.generatedCount > 0 ? AppColors.redditOrange : .secondary)
                        }
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

                    Text("EVENT SOURCES")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                        .tracking(0.3)
                    eventSourceChips

                    HStack {
                        Spacer()
                        if hasOverride {
                            Button("Reset to defaults", action: resetDefaults)
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                                .underline()
                                .buttonStyle(.plain)
                        }
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

    private var peakDayChips: some View {
        HStack(spacing: 4) {
            ForEach(Array(zip(SubredditPeakSelection.allDays, SubredditPeakSelection.dayKeys)), id: \.0) { display, key in
                let isOn = effectivePeakDays.contains(key)
                Button(action: { toggleDay(key) }) {
                    Text(display)
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(isOn ? AppColors.redditOrange.opacity(hasOverride ? 0.12 : 0.06) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(isOn ? AppColors.redditOrange : Color(NSColor.separatorColor), lineWidth: 0.5)
                        )
                        .foregroundStyle(isOn ? AppColors.redditOrange : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func toggleDay(_ day: String) {
        sub.peakDaysOverride = SubredditPeakSelection.toggledDay(day, in: sub.peakDaysOverride)
    }

    private var peakHourChips: some View {
        let columns = [GridItem(.adaptive(minimum: 30), spacing: 3)]
        let hours = SubredditPeakSelection.displayHours
        return LazyVGrid(columns: columns, spacing: 3) {
            ForEach(hours, id: \.self) { hour in
                let isOn = effectivePeakHours.contains(hour)
                Button(action: { toggleHour(hour) }) {
                    Text("\(hour)")
                        .font(.system(size: 9, weight: .medium))
                        .frame(minWidth: 24)
                        .padding(.vertical, 3)
                        .background(isOn ? Color.green.opacity(hasOverride ? 0.12 : 0.06) : Color.clear)
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

    private var eventSourceChips: some View {
        HStack(spacing: 6) {
            sourceChip(label: "Manual", count: eventSourceSummary.manualCount, color: .secondary)
            sourceChip(label: "Auto", count: eventSourceSummary.generatedCount, color: AppColors.redditOrange)
        }
    }

    private func sourceChip(label: String, count: Int, color: Color) -> some View {
        Text("\(count) \(label.lowercased())")
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(count > 0 ? color.opacity(0.10) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(count > 0 ? color : Color(NSColor.separatorColor), lineWidth: 0.5)
            )
            .foregroundStyle(count > 0 ? color : .secondary)
    }

    private func toggleHour(_ hour: Int) {
        sub.peakHoursUtcOverride = SubredditPeakSelection.toggledHour(hour, in: sub.peakHoursUtcOverride)
    }

    private var peakDaysSummary: String {
        SubredditPeakSelection.peakDaysSummary(effectivePeakDays: effectivePeakDays, hasOverride: hasOverride)
    }

    private func resetDefaults() {
        sub.peakDaysOverride = nil
        sub.peakHoursUtcOverride = nil
    }

    private var hasOverride: Bool {
        SubredditPeakSelection.hasOverride(days: sub.peakDaysOverride, hours: sub.peakHoursUtcOverride)
    }

    private var effectivePeakDays: [String] {
        SubredditPeakSelection.effectivePeakDays(override: sub.peakDaysOverride, peakInfo: peakInfo)
    }

    private var effectivePeakHours: [Int] {
        SubredditPeakSelection.effectivePeakHours(override: sub.peakHoursUtcOverride, peakInfo: peakInfo)
    }

    private var eventSourceSummary: EventSourceSummary {
        EventSourceSummary.active(events: sub.events)
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
        SubredditPersistenceActions.reorder(
            source: source,
            target: target,
            subreddits: subreddits,
            modelContext: modelContext
        )
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}
