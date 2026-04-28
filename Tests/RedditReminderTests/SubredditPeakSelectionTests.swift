import Testing
@testable import RedditReminder

@Test func subredditPeakSelectionAddsAndRemovesDayOverrides() {
    #expect(SubredditPeakSelection.toggledDay("mon", in: nil) == ["mon"])
    #expect(SubredditPeakSelection.toggledDay("wed", in: ["mon"]) == ["mon", "wed"])
    #expect(SubredditPeakSelection.toggledDay("mon", in: ["mon", "wed"]) == ["wed"])
    #expect(SubredditPeakSelection.toggledDay("mon", in: ["mon"]) == nil)
}

@Test func subredditPeakSelectionAddsSortsAndRemovesHourOverrides() {
    #expect(SubredditPeakSelection.toggledHour(18, in: nil) == [18])
    #expect(SubredditPeakSelection.toggledHour(14, in: [18]) == [14, 18])
    #expect(SubredditPeakSelection.toggledHour(18, in: [14, 18]) == [14])
    #expect(SubredditPeakSelection.toggledHour(18, in: [18]) == nil)
}

@Test func subredditPeakSelectionFormatsPeakDaySummary() {
    #expect(SubredditPeakSelection.peakDaysSummary(effectivePeakDays: [], hasOverride: false) == "no defaults")
    #expect(SubredditPeakSelection.peakDaysSummary(
        effectivePeakDays: ["mon", "wed"],
        hasOverride: false
    ) == "Mon Wed defaults")
    #expect(SubredditPeakSelection.peakDaysSummary(
        effectivePeakDays: ["fri"],
        hasOverride: true
    ) == "Fri")
}

@Test func subredditPeakSelectionResolvesOverridesAndDefaults() {
    let info = PeakInfo(peakDays: ["tue"], peakHoursUtc: [14, 15])

    #expect(SubredditPeakSelection.hasOverride(days: nil, hours: nil) == false)
    #expect(SubredditPeakSelection.hasOverride(days: ["fri"], hours: nil))
    #expect(SubredditPeakSelection.effectivePeakDays(override: nil, peakInfo: info) == ["tue"])
    #expect(SubredditPeakSelection.effectivePeakDays(override: ["fri"], peakInfo: info) == ["fri"])
    #expect(SubredditPeakSelection.effectivePeakDays(override: nil, peakInfo: nil) == [])
    #expect(SubredditPeakSelection.effectivePeakHours(override: nil, peakInfo: info) == [14, 15])
    #expect(SubredditPeakSelection.effectivePeakHours(override: [20], peakInfo: info) == [20])
    #expect(SubredditPeakSelection.effectivePeakHours(override: nil, peakInfo: nil) == [])
}

@Test func subredditPeakSelectionDefinesDisplayOptions() {
    #expect(SubredditPeakSelection.allDays.count == SubredditPeakSelection.dayKeys.count)
    #expect(SubredditPeakSelection.dayKeys == ["mon", "tue", "wed", "thu", "fri", "sat", "sun"])
    #expect(SubredditPeakSelection.displayHours == SubredditPeakSelection.displayHours.sorted())
}
