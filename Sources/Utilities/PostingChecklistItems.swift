import Foundation

enum PostingChecklistItems {
  static func cleaned(from rawItems: [String]) -> [String] {
    rawItems
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }

  static func cleaned(from checklist: String?) -> [String] {
    cleaned(from: checklist?.components(separatedBy: .newlines) ?? [])
  }
}
