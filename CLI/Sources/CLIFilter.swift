import Foundation

enum CLIFilter {
  static func items<T>(_ items: [T], query: String?, searchableText: (T) -> String) -> [T] {
    guard let normalized = query?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
      !normalized.isEmpty
    else { return items }
    return items.filter { searchableText($0).lowercased().contains(normalized) }
  }
}
