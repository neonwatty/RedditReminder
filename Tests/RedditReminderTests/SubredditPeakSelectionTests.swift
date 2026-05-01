import Testing
import Foundation
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

@Test func localHourToUtcConvertsCorrectly() {
    // PDT is UTC-7
    let pdt = TimeZone(identifier: "America/Los_Angeles")!
    // In summer (PDT): local 9 AM = UTC 16
    let summer = DateComponents(calendar: .current, year: 2024, month: 7, day: 1).date!
    #expect(SubredditPeakSelection.localHourToUtc(9, timeZone: pdt, referenceDate: summer) == 16)
    #expect(SubredditPeakSelection.localHourToUtc(0, timeZone: pdt, referenceDate: summer) == 7)
    #expect(SubredditPeakSelection.localHourToUtc(20, timeZone: pdt, referenceDate: summer) == 3)
}

@Test func utcHourToLocalConvertsCorrectly() {
    let pdt = TimeZone(identifier: "America/Los_Angeles")!
    let summer = DateComponents(calendar: .current, year: 2024, month: 7, day: 1).date!
    #expect(SubredditPeakSelection.utcHourToLocal(16, timeZone: pdt, referenceDate: summer) == 9)
    #expect(SubredditPeakSelection.utcHourToLocal(7, timeZone: pdt, referenceDate: summer) == 0)
    #expect(SubredditPeakSelection.utcHourToLocal(3, timeZone: pdt, referenceDate: summer) == 20)
}

@Test func timezoneConversionRoundTrips() {
    let tokyo = TimeZone(identifier: "Asia/Tokyo")!
    let ref = DateComponents(calendar: .current, year: 2024, month: 7, day: 1).date!
    for hour in 0..<24 {
        let utc = SubredditPeakSelection.localHourToUtc(hour, timeZone: tokyo, referenceDate: ref)
        let back = SubredditPeakSelection.utcHourToLocal(utc, timeZone: tokyo, referenceDate: ref)
        #expect(back == hour)
    }
}

@Test func halfHourTimezoneConversion() {
    // India is UTC+5:30 — rounds to nearest hour
    let india = TimeZone(identifier: "Asia/Kolkata")!
    let ref = DateComponents(calendar: .current, year: 2024, month: 7, day: 1).date!
    // Local 9 AM IST = UTC 3:30 AM → rounds to UTC 3 (truncated by Calendar.component(.hour))
    let utc = SubredditPeakSelection.localHourToUtc(9, timeZone: india, referenceDate: ref)
    #expect(utc == 3 || utc == 4) // Either rounding direction is acceptable
}

@Test func presetsDefineExpectedPatterns() {
    let presets = SubredditPeakSelection.presets
    #expect(presets.count == 4)
    #expect(presets[0].label == "Weekday AM")
    #expect(presets[0].days == ["mon", "tue", "wed", "thu", "fri"])
    #expect(presets[0].localHours == [8, 9, 10, 11])

    #expect(presets[1].label == "Weekday PM")
    #expect(presets[1].days == ["mon", "tue", "wed", "thu", "fri"])
    #expect(presets[1].localHours == [17, 18, 19, 20])

    #expect(presets[2].label == "Weekend midday")
    #expect(presets[2].days == ["sat", "sun"])
    #expect(presets[2].localHours == [10, 11, 12, 13, 14])

    #expect(presets[3].label == "Daily prime")
    #expect(presets[3].days == ["mon", "tue", "wed", "thu", "fri", "sat", "sun"])
    #expect(presets[3].localHours == [9, 10, 11, 12])
}

@Test func applyPresetConvertsToUtc() {
    let pdt = TimeZone(identifier: "America/Los_Angeles")!
    let summer = DateComponents(calendar: .current, year: 2024, month: 7, day: 1).date!
    let preset = SubredditPeakSelection.presets[0] // Weekday AM: local 8-11

    let result = SubredditPeakSelection.applyPreset(preset, timeZone: pdt, referenceDate: summer)

    #expect(result.days == ["mon", "tue", "wed", "thu", "fri"])
    // PDT is UTC-7: local 8=UTC15, 9=UTC16, 10=UTC17, 11=UTC18
    #expect(result.utcHours == [15, 16, 17, 18])
}

@Test func suggestedDefaultsReturnsWeekdayAMPreset() {
    let suggested = SubredditPeakSelection.suggestedDefaults(timeZone: .current)
    #expect(suggested.days == ["mon", "tue", "wed", "thu", "fri"])
    #expect(suggested.localHours == [8, 9, 10, 11])
}

@Test func suggestedDefaultsUtcMatchesPresetApplication() {
    let pdt = TimeZone(identifier: "America/Los_Angeles")!
    let summer = DateComponents(calendar: .current, year: 2024, month: 7, day: 1).date!

    let suggested = SubredditPeakSelection.suggestedDefaults(timeZone: pdt, referenceDate: summer)
    let applied = SubredditPeakSelection.applyPreset(SubredditPeakSelection.presets[0], timeZone: pdt, referenceDate: summer)

    #expect(suggested.utcHours == applied.utcHours)
    #expect(suggested.days == applied.days)
}

@Test func needsSuggestedDefaultsReturnsTrueWhenBlank() {
    #expect(SubredditPeakSelection.needsSuggestedDefaults(override: nil, peakInfo: nil) == true)
    #expect(SubredditPeakSelection.needsSuggestedDefaults(override: ["mon"], peakInfo: nil) == false)
    let info = PeakInfo(peakDays: ["tue"], peakHoursUtc: [14])
    #expect(SubredditPeakSelection.needsSuggestedDefaults(override: nil, peakInfo: info) == false)
}
