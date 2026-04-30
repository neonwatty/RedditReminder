import SwiftUI

enum UrgencyPresentation {
  static func color(for urgency: UrgencyLevel) -> Color? {
    switch urgency {
    case .active, .high:
      return AppColors.redditOrange
    case .medium:
      return Color.green
    case .none, .low, .expired:
      return nil
    }
  }

  static func label(for urgency: UrgencyLevel) -> String {
    switch urgency {
    case .active:
      return "Posting window is active"
    case .high:
      return "Posting window soon"
    case .medium:
      return "Posting window later today"
    case .low:
      return "Posting window within 24 hours"
    case .expired:
      return "Posting window has passed"
    case .none:
      return "No upcoming posting window"
    }
  }

  static func accessibilityLabel(for urgency: UrgencyLevel) -> String {
    "Urgency: \(label(for: urgency))"
  }
}
