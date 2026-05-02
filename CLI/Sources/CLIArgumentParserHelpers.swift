import Foundation

extension CLIArgumentParser {
  mutating func consumeFlag(_ flag: String) -> Bool {
    guard let index = arguments.firstIndex(of: flag) else { return false }
    arguments.remove(at: index)
    return true
  }

  func splitCSV(_ value: String?) -> [String] {
    value?
      .split(separator: ",")
      .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty } ?? []
  }

  func normalizedOptional(_ value: String?) -> String? {
    let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return trimmed.isEmpty ? nil : trimmed
  }

  func firstRemainingFlag() -> String? {
    arguments.first { $0.hasPrefix("--") }
  }

  mutating func consumeRemainingText() -> String {
    let text = arguments.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    arguments.removeAll()
    return text
  }

  func parsedDate(_ value: String, label: String) throws -> Date {
    if let date = ISO8601DateFormatter().date(from: value) { return date }
    throw CLIError.validation("\(label) must be ISO-8601, for example 2026-05-02T15:00:00Z.")
  }

  func parsedNonNegativeInt(_ value: String, label: String) throws -> Int {
    guard let number = Int(value), number >= 0 else {
      throw CLIError.validation("\(label) must be a non-negative integer.")
    }
    return number
  }

  mutating func consumeLimit(default defaultValue: Int = 20) throws -> Int {
    guard let value = consumeOptionalValue(for: "--limit") else { return defaultValue }
    guard let limit = Int(value), limit > 0 else {
      throw CLIError.usage("--limit must be a positive integer.")
    }
    return limit
  }
}
