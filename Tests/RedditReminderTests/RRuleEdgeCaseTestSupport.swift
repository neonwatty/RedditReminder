import Foundation

/// Matches RRuleHelperTests convention: fixed date in America/New_York.
func rruleEdgeDate(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
    var c = DateComponents()
    c.year = y
    c.month = m
    c.day = d
    c.hour = h
    c.minute = min
    c.timeZone = TimeZone(identifier: "America/New_York")
    return Calendar.current.date(from: c)!
}

/// Fixed date in local timezone for tests that assert Calendar.current components.
func rruleEdgeLocalDate(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
    var c = DateComponents()
    c.year = y
    c.month = m
    c.day = d
    c.hour = h
    c.minute = min
    c.timeZone = Calendar.current.timeZone
    return Calendar.current.date(from: c)!
}

func rruleDate(
    _ y: Int,
    _ m: Int,
    _ d: Int,
    _ h: Int,
    _ min: Int,
    timeZone: TimeZone
) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    return calendar.date(from: DateComponents(
        timeZone: timeZone,
        year: y,
        month: m,
        day: d,
        hour: h,
        minute: min
    ))!
}
