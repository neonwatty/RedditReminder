import SwiftUI

struct OnboardingEmptyView: View {
    let onSetupChannels: () -> Void
    let onNewCapture: () -> Void
    let onSetupNotifications: () -> Void

    static let titleText = "Set up your posting channels"
    static let descriptionText = "Add a subreddit first, then create a capture and turn on reminders for posting windows."
    static let primaryButtonText = "Add Channel"
    static let secondaryButtonText = "New Capture"
    static let notificationsButtonText = "Enable Reminders"
    static let setupSteps = [
        "Add a subreddit channel",
        "Create your first capture",
        "Enable reminder notifications",
    ]

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "lightbulb.max")
                .font(.system(size: 28))
                .foregroundStyle(AppColors.redditOrange.opacity(0.7))

            VStack(spacing: 6) {
                Text(Self.titleText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text(Self.descriptionText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            VStack(spacing: 8) {
                Button(action: onSetupChannels) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .semibold))
                        Text(Self.primaryButtonText)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(AppColors.redditOrange)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add channel")
                .accessibilityIdentifier("onboarding.setupChannels")

                HStack(spacing: 14) {
                    Button(action: onNewCapture) {
                        Text(Self.secondaryButtonText)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppColors.redditOrange)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("New capture")
                    .accessibilityIdentifier("onboarding.newCapture")

                    Button(action: onSetupNotifications) {
                        Text(Self.notificationsButtonText)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppColors.redditOrange)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Enable reminders")
                    .accessibilityIdentifier("onboarding.setupNotifications")
                }
            }

            // Quick-start hints
            VStack(alignment: .leading, spacing: 6) {
                hintRow(icon: "tag", text: Self.setupSteps[0])
                hintRow(icon: "text.bubble", text: Self.setupSteps[1])
                hintRow(icon: "bell", text: Self.setupSteps[2])
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
