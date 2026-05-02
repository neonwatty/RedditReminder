import Foundation
import SwiftData

struct PeakInfo {
  let peakDays: [String]
  let peakHoursUtc: [Int]
}

@MainActor
final class HeuristicsStore {
  private var bundled: [String: PeakInfo] = [:]
  private var overrides: [String: PeakInfo] = [:]
  private let logsMissingResource: Bool

  init(bundle: Bundle = .main, logsMissingResource: Bool = true) {
    self.logsMissingResource = logsMissingResource
    loadBundled(from: bundle)
  }

  func peakInfo(for subreddit: String) -> PeakInfo? {
    if let override = overrides[subreddit] { return override }
    return bundled[subreddit]
  }

  func peakInfo(for subreddit: Subreddit) -> PeakInfo? {
    let bundledInfo = peakInfo(for: subreddit.name)
    let days = subreddit.peakDaysOverride ?? bundledInfo?.peakDays
    let hours = subreddit.peakHoursUtcOverride ?? bundledInfo?.peakHoursUtc

    guard let days, let hours, !days.isEmpty, !hours.isEmpty else { return nil }
    return PeakInfo(peakDays: normalizedDays(days), peakHoursUtc: normalizedHours(hours))
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

  func syncGeneratedEvents(
    for subreddits: [Subreddit],
    context: ModelContext,
    defaultLeadTimeMinutes: Int
  ) throws {
    for subreddit in subreddits {
      try syncGeneratedEvents(
        for: subreddit,
        context: context,
        defaultLeadTimeMinutes: defaultLeadTimeMinutes
      )
    }
  }

  func syncGeneratedEvents(
    for subreddit: Subreddit,
    context: ModelContext,
    defaultLeadTimeMinutes: Int
  ) throws {
    let peak = peakInfo(for: subreddit)
    let desired = desiredEvents(for: peak)
    let desiredKeys = Set(desired.map(\.key))

    for event in subreddit.events where event.isGeneratedFromHeuristics {
      guard let key = event.generationKey, desiredKeys.contains(key) else {
        context.delete(event)
        continue
      }
    }

    for spec in desired {
      let existing = subreddit.events.first {
        $0.isGeneratedFromHeuristics && $0.generationKey == spec.key
      }

      let event = existing ?? SubredditEvent(
        name: spec.name,
        subreddit: subreddit,
        rrule: spec.rrule,
        recurrenceHour: spec.hour,
        recurrenceMinute: 0,
        recurrenceTimeZoneIdentifier: "UTC",
        reminderLeadMinutes: defaultLeadTimeMinutes,
        isActive: true,
        isGeneratedFromHeuristics: true,
        generationKey: spec.key
      )

      event.name = spec.name
      event.rrule = spec.rrule
      event.oneOffDate = nil
      event.recurrenceHour = spec.hour
      event.recurrenceMinute = 0
      event.recurrenceTimeZoneIdentifier = "UTC"
      event.reminderLeadMinutes = defaultLeadTimeMinutes
      event.isActive = true
      event.isGeneratedFromHeuristics = true
      event.generationKey = spec.key

      if existing == nil {
        context.insert(event)
      }
    }

    if context.hasChanges {
      try context.save()
    }
  }

  private func loadBundled(from bundle: Bundle) {
    guard let url = bundle.url(forResource: "peak-times", withExtension: "json")
      ?? Self.fallbackPeakTimesURL()
    else {
      if logsMissingResource {
        NSLog("RedditReminder: peak-times.json not found in bundle")
      }
      return
    }

    let json: [String: [String: Any]]
    do {
      let data = try Data(contentsOf: url)
      guard let parsed = try JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] else {
        NSLog("RedditReminder: peak-times.json has unexpected structure")
        return
      }
      json = parsed
    } catch {
      NSLog("RedditReminder: failed to load peak-times.json: \(error)")
      return
    }

    for (sub, info) in json {
      if let days = info["peak_days"] as? [String],
        let hours = info["peak_hours_utc"] as? [Int]
      {
        bundled[sub] = PeakInfo(peakDays: days, peakHoursUtc: hours)
      }
    }
  }

  private static func fallbackPeakTimesURL() -> URL? {
    let fileManager = FileManager.default
    let currentDirectory = URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
    let executableDirectory = URL(fileURLWithPath: CommandLine.arguments.first ?? "")
      .deletingLastPathComponent()
    let candidates = [
      currentDirectory.appendingPathComponent("Resources/peak-times.json"),
      executableDirectory.appendingPathComponent("Resources/peak-times.json"),
      executableDirectory.appendingPathComponent("RedditReminderResources/peak-times.json"),
    ]
    return candidates.first { fileManager.fileExists(atPath: $0.path) }
  }

  private struct GeneratedEventSpec {
    let key: String
    let name: String
    let rrule: String
    let hour: Int
  }

  private func desiredEvents(for peak: PeakInfo?) -> [GeneratedEventSpec] {
    guard let peak else { return [] }

    var specs: [GeneratedEventSpec] = []
    for day in normalizedDays(peak.peakDays) {
      guard let byday = Self.rruleDayAbbrev(day) else { continue }
      for hour in normalizedHours(peak.peakHoursUtc) {
        specs.append(GeneratedEventSpec(
          key: "heuristic:\(day):\(hour)",
          name: "Peak posting window",
          rrule: "FREQ=WEEKLY;BYDAY=\(byday)",
          hour: hour
        ))
      }
    }
    return specs
  }

  private func normalizedDays(_ days: [String]) -> [String] {
    var seen: Set<String> = []
    return days.compactMap { day in
      let key = String(day.lowercased().prefix(3))
      guard Self.rruleDayAbbrev(key) != nil, !seen.contains(key) else { return nil }
      seen.insert(key)
      return key
    }
  }

  private func normalizedHours(_ hours: [Int]) -> [Int] {
    Array(Set(hours.filter { (0...23).contains($0) })).sorted()
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

  private static func rruleDayAbbrev(_ day: String) -> String? {
    switch day {
    case "sun": return "SU"
    case "mon": return "MO"
    case "tue": return "TU"
    case "wed": return "WE"
    case "thu": return "TH"
    case "fri": return "FR"
    case "sat": return "SA"
    default: return nil
    }
  }
}
