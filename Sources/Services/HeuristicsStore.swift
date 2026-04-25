import Foundation

struct PeakInfo {
  let peakDays: [String]
  let peakHoursUtc: [Int]
}

@MainActor
final class HeuristicsStore {
  private var bundled: [String: PeakInfo] = [:]
  private var overrides: [String: PeakInfo] = [:]

  init(bundle: Bundle = .main) {
    loadBundled(from: bundle)
  }

  func peakInfo(for subreddit: String) -> PeakInfo? {
    if let override = overrides[subreddit] { return override }
    return bundled[subreddit]
  }

  func setOverride(for subreddit: String, peakDays: [String], peakHoursUtc: [Int]) {
    overrides[subreddit] = PeakInfo(peakDays: peakDays, peakHoursUtc: peakHoursUtc)
  }

  func clearOverride(for subreddit: String) {
    overrides.removeValue(forKey: subreddit)
  }

  func isPeakWindow(for subreddit: String, at date: Date) -> Bool {
    guard let peak = peakInfo(for: subreddit) else { return false }

    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!

    let hour = cal.component(.hour, from: date)
    guard peak.peakHoursUtc.contains(hour) else { return false }

    let weekday = cal.component(.weekday, from: date)
    let dayAbbrev = Self.weekdayAbbrev(weekday)
    return peak.peakDays.contains(dayAbbrev)
  }

  private func loadBundled(from bundle: Bundle) {
    guard let url = bundle.url(forResource: "peak-times", withExtension: "json"),
      let data = try? Data(contentsOf: url),
      let json = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]]
    else { return }

    for (sub, info) in json {
      if let days = info["peak_days"] as? [String],
        let hours = info["peak_hours_utc"] as? [Int]
      {
        bundled[sub] = PeakInfo(peakDays: days, peakHoursUtc: hours)
      }
    }
  }

  private static func weekdayAbbrev(_ weekday: Int) -> String {
    switch weekday {
    case 1: return "sun"
    case 2: return "mon"
    case 3: return "tue"
    case 4: return "wed"
    case 5: return "thu"
    case 6: return "fri"
    case 7: return "sat"
    default: return ""
    }
  }
}
