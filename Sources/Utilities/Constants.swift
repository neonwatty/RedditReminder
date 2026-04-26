import Foundation
import AppKit

enum SidebarState: String, CaseIterable {
  case strip
  case glance
  case browse
  case capture
  case settings
  case channels
}

enum SidebarConstants {
  static let stripWidth: CGFloat = 24
  static let glanceWidth: CGFloat = 200
  static let browseWidth: CGFloat = 320
  static let captureWidth: CGFloat = 480
  static let settingsWidth: CGFloat = 320
  static let channelsWidth: CGFloat = 320
  static let animationDuration: CGFloat = 0.35
  static let defaultAutoCollapseMinutes: Int = 5

  static func width(for state: SidebarState) -> CGFloat {
    switch state {
    case .strip: return stripWidth
    case .glance: return glanceWidth
    case .browse: return browseWidth
    case .capture: return captureWidth
    case .settings: return settingsWidth
    case .channels: return channelsWidth
    }
  }

  static func height(for state: SidebarState, screenHeight: CGFloat) -> CGFloat {
    switch state {
    case .strip: return screenHeight
    case .glance: return 240
    case .browse: return screenHeight * 0.85
    case .capture: return screenHeight * 0.70
    case .settings: return 340
    case .channels: return screenHeight * 0.85
    }
  }
}

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
  static let green = NSColor(red: 0.13, green: 0.77, blue: 0.37, alpha: 1.0)
  static let blue = NSColor(red: 0.29, green: 0.62, blue: 1.0, alpha: 1.0)
  static let purple = NSColor(red: 0.66, green: 0.33, blue: 0.97, alpha: 1.0)
  static let gold = NSColor(red: 0.81, green: 0.60, blue: 0.03, alpha: 1.0)
  static let pink = NSColor(red: 0.93, green: 0.29, blue: 0.60, alpha: 1.0)
}

enum MediaConstants {
  static let thumbnailMaxSize: CGFloat = 200
  static let supportedImageTypes = ["png", "jpg", "jpeg", "gif"]
  static let supportedVideoTypes = ["mp4", "mov"]
  static var supportedTypes: [String] { supportedImageTypes + supportedVideoTypes }
}
