import Foundation

enum SubredditPeakSelection {
    static let allDays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    static let dayKeys = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]
    static let displayHours = [0, 2, 4, 6, 8, 10, 12, 14, 15, 16, 17, 18, 20, 22]

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
}
