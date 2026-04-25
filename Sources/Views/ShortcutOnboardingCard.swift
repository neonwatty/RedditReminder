import SwiftUI

struct ShortcutOnboardingCard: View {
  let onDismiss: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Image(systemName: "keyboard")
          .font(.system(size: 14))
          .foregroundStyle(Color(nsColor: AppColors.reddit))
        Text("⌘⇧R toggles the sidebar")
          .font(.system(size: 12, weight: .bold))
          .foregroundStyle(.primary)
      }

      Text(
        "Use this shortcut from anywhere to show or hide RedditReminder. It requires Accessibility permission in System Settings."
      )
      .font(.system(size: 11))
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)

      HStack(spacing: 8) {
        Button(action: openAccessibilitySettings) {
          Text("Open System Settings")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(nsColor: AppColors.reddit))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)

        Button(action: onDismiss) {
          Text("Dismiss")
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
      }
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(nsColor: AppColors.blue).opacity(0.1))
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(Color(nsColor: AppColors.blue).opacity(0.3), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }

  private func openAccessibilitySettings() {
    if let url = URL(
      string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    {
      NSWorkspace.shared.open(url)
    }
  }
}
