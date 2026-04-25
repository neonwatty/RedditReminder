import SwiftUI

struct ShortcutOnboardingCard: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "keyboard")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(StickerColors.gold)
                Text("\u{2318}\u{21E7}R toggles the sidebar")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(StickerColors.textPrimary)
            }

            Text("Use this shortcut from anywhere to show or hide RedditReminder. It requires Accessibility permission in System Settings.")
                .font(.system(size: 11))
                .foregroundStyle(StickerColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Button(action: openAccessibilitySettings) {
                    Text("Open System Settings")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(StickerColors.gold)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(StickerColors.border, lineWidth: 2)
                        )
                }
                .buttonStyle(.plain)

                Button(action: onDismiss) {
                    Text("Dismiss")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(StickerColors.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .stickerCard(borderColor: StickerColors.gold)
    }

    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
