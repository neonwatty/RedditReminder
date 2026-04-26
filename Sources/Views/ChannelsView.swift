import SwiftUI
import SwiftData

struct ChannelsView: View {
    @Query(sort: \Subreddit.name) private var subreddits: [Subreddit]
    @Environment(\.modelContext) private var modelContext

    @State private var expandedSubredditId: UUID?
    @State private var newSubredditName = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                addRow
                redditSection
                discordSection
                socialSection
            }
            .padding(12)
        }
    }

    // MARK: - Add Row

    private var addRow: some View {
        HStack(spacing: 6) {
            TextField("r/NewSubreddit", text: $newSubredditName)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .stickerInput()
                .onSubmit { addSubreddit() }

            Button(action: addSubreddit) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(canAdd ? StickerColors.green : StickerColors.textSecondary)
            }
            .buttonStyle(.plain)
            .disabled(!canAdd)
        }
    }

    private var canAdd: Bool {
        let trimmed = newSubredditName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        let name = trimmed.hasPrefix("r/") ? trimmed : "r/\(trimmed)"
        return !subreddits.contains(where: { $0.name.lowercased() == name.lowercased() })
    }

    private func addSubreddit() {
        let trimmed = newSubredditName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let name = trimmed.hasPrefix("r/") ? trimmed : "r/\(trimmed)"
        guard !subreddits.contains(where: { $0.name.lowercased() == name.lowercased() }) else { return }

        let sub = Subreddit(name: name)
        modelContext.insert(sub)
        do {
            try modelContext.save()
            newSubredditName = ""
        } catch {
            modelContext.rollback()
            NSLog("RedditReminder: failed to add subreddit: \(error)")
        }
    }

    // MARK: - Reddit Section

    private var redditSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            stickerSectionLabel("Reddit")
            ForEach(subreddits, id: \.id) { sub in
                if expandedSubredditId == sub.id {
                    expandedRow(sub)
                } else {
                    collapsedRow(sub)
                }
            }
        }
    }

    private func collapsedRow(_ sub: Subreddit) -> some View {
        Button(action: { expandedSubredditId = sub.id }) {
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(StickerColors.reddit)
                        .frame(width: 8, height: 8)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10))
                        .foregroundStyle(StickerColors.textSecondary)
                    Text(sub.name)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(StickerColors.textPrimary)
                }
                Spacer()
                Text(peakDaysSummary(sub))
                    .foregroundStyle(StickerColors.textSecondary)
                    .stickerBadge(color: StickerColors.border)
            }
        }
        .buttonStyle(.plain)
        .padding(10)
        .stickerCard()
    }

    private func expandedRow(_ sub: Subreddit) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(StickerColors.reddit)
                        .frame(width: 8, height: 8)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                        .foregroundStyle(StickerColors.gold)
                    Text(sub.name)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(StickerColors.textPrimary)
                }
                Spacer()
                Button(action: { deleteSubreddit(sub) }) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(StickerColors.reddit)
                }
                .buttonStyle(.plain)
            }

            // Name
            stickerSectionLabel("Name", size: 9)
            TextField("Subreddit name", text: Binding(
                get: { sub.name },
                set: { newName in
                    sub.name = newName
                    try? modelContext.save()
                }
            ))
            .textFieldStyle(.plain)
            .font(.system(size: 12))
            .stickerInput()

            // Peak Days
            stickerSectionLabel("Peak Days", size: 9)
            peakDayChips(sub)

            // Peak Hours
            stickerSectionLabel("Peak Hours (UTC)", size: 9)
            peakHourChips(sub)

            // Reset
            HStack {
                Spacer()
                Button(action: { resetDefaults(sub) }) {
                    Text("Reset to defaults")
                        .font(.system(size: 9))
                        .foregroundStyle(StickerColors.textSecondary)
                        .underline()
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .stickerCard(borderColor: StickerColors.gold)
        .onTapGesture { } // absorb taps so card doesn't collapse
    }

    // MARK: - Peak Day Chips

    private static let allDays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    private static let dayKeys = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]

    private func peakDayChips(_ sub: Subreddit) -> some View {
        HStack(spacing: 4) {
            ForEach(Array(zip(Self.allDays, Self.dayKeys)), id: \.0) { display, key in
                let isOn = sub.peakDaysOverride?.contains(key) ?? false
                Button(action: { toggleDay(key, on: sub) }) {
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

    private func toggleDay(_ day: String, on sub: Subreddit) {
        var days = sub.peakDaysOverride ?? []
        if days.contains(day) {
            days.removeAll { $0 == day }
        } else {
            days.append(day)
        }
        sub.peakDaysOverride = days.isEmpty ? nil : days
        try? modelContext.save()
    }

    // MARK: - Peak Hour Chips

    private static let displayHours = [0, 2, 4, 6, 8, 10, 12, 14, 15, 16, 17, 18, 20, 22]

    private func peakHourChips(_ sub: Subreddit) -> some View {
        let columns = [GridItem(.adaptive(minimum: 30), spacing: 3)]
        return LazyVGrid(columns: columns, spacing: 3) {
            ForEach(Self.displayHours, id: \.self) { hour in
                let isOn = sub.peakHoursUtcOverride?.contains(hour) ?? false
                Button(action: { toggleHour(hour, on: sub) }) {
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

    private func toggleHour(_ hour: Int, on sub: Subreddit) {
        var hours = sub.peakHoursUtcOverride ?? []
        if hours.contains(hour) {
            hours.removeAll { $0 == hour }
        } else {
            hours.append(hour)
            hours.sort()
        }
        sub.peakHoursUtcOverride = hours.isEmpty ? nil : hours
        try? modelContext.save()
    }

    // MARK: - Helpers

    private func peakDaysSummary(_ sub: Subreddit) -> String {
        guard let days = sub.peakDaysOverride, !days.isEmpty else { return "defaults" }
        return days.map { $0.prefix(3).capitalized }.joined(separator: " ")
    }

    private func deleteSubreddit(_ sub: Subreddit) {
        expandedSubredditId = nil
        modelContext.delete(sub)
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            NSLog("RedditReminder: failed to delete subreddit: \(error)")
        }
    }

    private func resetDefaults(_ sub: Subreddit) {
        sub.peakDaysOverride = nil
        sub.peakHoursUtcOverride = nil
        try? modelContext.save()
    }

    // MARK: - Placeholder Sections

    private var discordSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            stickerSectionLabel("Discord")
            placeholderRow(dot: Color(red: 0.35, green: 0.40, blue: 0.95), name: "#show-and-tell")
        }
        .padding(.top, 8)
    }

    private var socialSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            stickerSectionLabel("Social")
            placeholderRow(dot: StickerColors.blue, name: "Twitter/X")
        }
        .padding(.top, 8)
    }

    private func placeholderRow(dot: Color, name: String) -> some View {
        HStack {
            HStack(spacing: 8) {
                Circle().fill(dot).frame(width: 8, height: 8)
                Text(name)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(StickerColors.textPrimary)
            }
            Spacer()
            Text("coming soon")
                .font(.system(size: 9))
                .foregroundStyle(StickerColors.textSecondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(StickerColors.border)
                .clipShape(Capsule())
        }
        .padding(10)
        .stickerCard()
        .opacity(0.4)
    }
}
