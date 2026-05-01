import Foundation

enum SubredditPeakSelection {
    static let allDays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    static let dayKeys = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]
    static let displayHours = Array(0...23)

    static func toggledDay(_ day: String, in override: [String]?) -> [String]? {
        var days = override ?? []
        if days.contains(day) {
            days.removeAll { $0 == day }
        } else {
            days.append(day)
        }
        return days.isEmpty ? nil : days
    }

    static func toggledHour(_ hour: Int, in override: [Int]?) -> [Int]? {
        var hours = override ?? []
        if hours.contains(hour) {
            hours.removeAll { $0 == hour }
        } else {
            hours.append(hour)
            hours.sort()
        }
        return hours.isEmpty ? nil : hours
    }

    static func peakDaysSummary(effectivePeakDays: [String], hasOverride: Bool) -> String {
        guard !effectivePeakDays.isEmpty else { return "no defaults" }
        let suffix = hasOverride ? "" : " defaults"
        return effectivePeakDays.map { $0.prefix(3).capitalized }.joined(separator: " ") + suffix
    }

    static func hasOverride(days: [String]?, hours: [Int]?) -> Bool {
        days != nil || hours != nil
    }

    static func effectivePeakDays(override: [String]?, peakInfo: PeakInfo?) -> [String] {
        override ?? peakInfo?.peakDays ?? []
    }

    static func effectivePeakHours(override: [Int]?, peakInfo: PeakInfo?) -> [Int] {
        override ?? peakInfo?.peakHoursUtc ?? []
    }

    static func localHourToUtc(_ localHour: Int, timeZone: TimeZone = .current, referenceDate: Date = Date()) -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let comps = cal.dateComponents([.year, .month, .day], from: referenceDate)
        var localComps = comps
        localComps.hour = localHour
        localComps.minute = 0
        guard let localDate = cal.date(from: localComps) else { return localHour }

        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(identifier: "UTC")!
        return utcCal.component(.hour, from: localDate)
    }

    static func utcHourToLocal(_ utcHour: Int, timeZone: TimeZone = .current, referenceDate: Date = Date()) -> Int {
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(identifier: "UTC")!
        let comps = utcCal.dateComponents([.year, .month, .day], from: referenceDate)
        var utcComps = comps
        utcComps.hour = utcHour
        utcComps.minute = 0
        guard let utcDate = utcCal.date(from: utcComps) else { return utcHour }

        var localCal = Calendar(identifier: .gregorian)
        localCal.timeZone = timeZone
        return localCal.component(.hour, from: utcDate)
    }

    static func utcHoursToLocal(_ utcHours: [Int], timeZone: TimeZone = .current, referenceDate: Date = Date()) -> [Int] {
        Array(Set(utcHours.map { utcHourToLocal($0, timeZone: timeZone, referenceDate: referenceDate) })).sorted()
    }

    struct PeakPreset {
        let label: String
        let days: [String]
        let localHours: [Int]
    }

    struct AppliedPreset {
        let days: [String]
        let utcHours: [Int]
    }

    static let presets: [PeakPreset] = [
        PeakPreset(label: "Weekday AM", days: ["mon", "tue", "wed", "thu", "fri"], localHours: [8, 9, 10, 11]),
        PeakPreset(label: "Weekday PM", days: ["mon", "tue", "wed", "thu", "fri"], localHours: [17, 18, 19, 20]),
        PeakPreset(label: "Weekend midday", days: ["sat", "sun"], localHours: [10, 11, 12, 13, 14]),
        PeakPreset(label: "Daily prime", days: ["mon", "tue", "wed", "thu", "fri", "sat", "sun"], localHours: [9, 10, 11, 12]),
    ]

    static func applyPreset(_ preset: PeakPreset, timeZone: TimeZone = .current, referenceDate: Date = Date()) -> AppliedPreset {
        let utcHours = preset.localHours.map { localHourToUtc($0, timeZone: timeZone, referenceDate: referenceDate) }.sorted()
        return AppliedPreset(days: preset.days, utcHours: utcHours)
    }

    struct SuggestedDefaults {
        let days: [String]
        let localHours: [Int]
        let utcHours: [Int]
    }

    static func suggestedDefaults(timeZone: TimeZone = .current, referenceDate: Date = Date()) -> SuggestedDefaults {
        let preset = presets[0] // Weekday AM
        let applied = applyPreset(preset, timeZone: timeZone, referenceDate: referenceDate)
        return SuggestedDefaults(days: applied.days, localHours: preset.localHours, utcHours: applied.utcHours)
    }

    static func needsSuggestedDefaults(daysOverride: [String]?, hoursOverride: [Int]?, peakInfo: PeakInfo?) -> Bool {
        daysOverride == nil && hoursOverride == nil && peakInfo == nil
    }
}
