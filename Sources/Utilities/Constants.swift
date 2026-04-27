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
}

enum MediaConstants {
  static let thumbnailMaxSize: CGFloat = 200
  static let supportedImageTypes = ["png", "jpg", "jpeg", "gif"]
  static let supportedVideoTypes = ["mp4", "mov"]
  static var supportedTypes: [String] { supportedImageTypes + supportedVideoTypes }
}
