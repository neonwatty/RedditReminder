import Foundation
import AppKit
import SwiftUI

enum UrgencyLevel: Comparable {
  case none
  case low
  case medium
  case high
  case active
  case expired
}

enum AppColors {
  static let reddit = NSColor(red: 1.0, green: 0.27, blue: 0.0, alpha: 1.0)
  static let redditOrange = Color(red: 1.0, green: 0.27, blue: 0.0)
  static let green = NSColor(red: 0.13, green: 0.77, blue: 0.37, alpha: 1.0)
  static let blue = NSColor(red: 0.29, green: 0.62, blue: 1.0, alpha: 1.0)
  static let purple = NSColor(red: 0.66, green: 0.33, blue: 0.97, alpha: 1.0)
  static let gold = NSColor(red: 0.81, green: 0.60, blue: 0.03, alpha: 1.0)
  static let pink = NSColor(red: 0.93, green: 0.29, blue: 0.60, alpha: 1.0)

  // Solid popover background — warm cream (light) / warm charcoal (dark)
  static let popoverBg = Color(nsColor: NSColor(name: nil) { appearance in
    appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
      ? NSColor(red: 0.13, green: 0.12, blue: 0.11, alpha: 1.0)
      : NSColor(red: 0.98, green: 0.97, blue: 0.95, alpha: 1.0)
  })
}

enum SettingsKey {
  static let defaultProjectId = "defaultProjectId"
  static let defaultLeadTimeMinutes = "defaultLeadTimeMinutes"
  static let notificationsEnabled = "notificationsEnabled"
    static let nudgeWhenEmpty = "nudgeWhenEmpty"
    static let globalShortcutIdentifier = "globalShortcutIdentifier"
    static let globalShortcutKeyCode = "globalShortcutKeyCode"
    static let globalShortcutModifiers = "globalShortcutModifiers"
    static let globalShortcutDisplay = "globalShortcutDisplay"
}

enum SettingsOptions {
  static let leadTimeMinutes = [15, 30, 60, 120]
}

enum SubredditName {
  static let minLength = 3
  static let maxLength = 21

  enum ValidationError: Error, Equatable {
    case empty
    case invalidCharacters
    case tooShort
    case tooLong

    var message: String {
      switch self {
      case .empty:
        return "Enter a subreddit name."
      case .invalidCharacters:
        return "Use only letters, numbers, and underscores."
      case .tooShort:
        return "Subreddit names must be at least \(SubredditName.minLength) characters."
      case .tooLong:
        return "Subreddit names must be \(SubredditName.maxLength) characters or fewer."
      }
    }
  }

  static func normalize(_ input: String) -> Result<String, ValidationError> {
    let candidate = canonicalCandidate(from: input)

    guard !candidate.isEmpty else { return .failure(.empty) }
    guard candidate.count >= minLength else { return .failure(.tooShort) }
    guard candidate.count <= maxLength else { return .failure(.tooLong) }

    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
    guard candidate.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
      return .failure(.invalidCharacters)
    }

    return .success("r/\(candidate)")
  }

  static func normalizedName(_ input: String) -> String? {
    if case .success(let name) = normalize(input) { return name }
    return nil
  }

  private static func canonicalCandidate(from input: String) -> String {
    var trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
      .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

    if let url = URL(string: trimmed), let host = url.host?.lowercased(),
       host == "reddit.com" || host == "www.reddit.com" || host.hasSuffix(".reddit.com") {
      let components = url.pathComponents.filter { $0 != "/" }
      if let markerIndex = components.firstIndex(where: { $0.lowercased() == "r" }),
         components.indices.contains(markerIndex + 1) {
        trimmed = components[markerIndex + 1]
      }
    }

    if trimmed.lowercased().hasPrefix("/r/") {
      trimmed.removeFirst(3)
    } else if trimmed.lowercased().hasPrefix("r/") {
      trimmed.removeFirst(2)
    }

    return trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
  }
}

struct InputFieldStyle: ViewModifier {
  var cornerRadius: CGFloat = 8

  func body(content: Content) -> some View {
    content
      .background(.quaternary.opacity(0.3))
      .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
      .overlay(
        RoundedRectangle(cornerRadius: cornerRadius)
          .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
      )
  }
}

extension View {
  func inputFieldStyle(cornerRadius: CGFloat = 8) -> some View {
    modifier(InputFieldStyle(cornerRadius: cornerRadius))
  }
}

enum MediaConstants {
  static let thumbnailMaxSize: CGFloat = 200
  static let supportedImageTypes = ["png", "jpg", "jpeg", "gif"]
  static let supportedVideoTypes = ["mp4", "mov"]
  static var supportedTypes: [String] { supportedImageTypes + supportedVideoTypes }
}
