import SwiftUI

struct OnboardingEmptyView: View {
    let onNewCapture: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "lightbulb.max")
                .font(.system(size: 28))
                .foregroundStyle(AppColors.redditOrange.opacity(0.7))

            VStack(spacing: 6) {
                Text("Capture ideas, post at the right time")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text("Save post ideas, tag subreddits, and get\nreminded when engagement peaks.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            Button(action: onNewCapture) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .semibold))
                    Text("New Capture")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(AppColors.redditOrange)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)

            // Quick-start hints
            VStack(alignment: .leading, spacing: 6) {
                hintRow(icon: "text.bubble", text: "Capture a post idea")
                hintRow(icon: "tag", text: "Tag target subreddits")
                hintRow(icon: "bell", text: "Get reminded at peak times")
            }
            .padding(.top, 4)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }

    private func hintRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(AppColors.redditOrange.opacity(0.6))
                .frame(width: 16)
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
    }
}
