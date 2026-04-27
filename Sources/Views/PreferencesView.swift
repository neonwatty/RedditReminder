import SwiftUI

struct PreferencesView: View {
    let notificationService: NotificationService

    @State private var selectedTab: Tab = .channels

    enum Tab: String, CaseIterable {
        case channels = "Channels"
        case general = "General"
        case notifications = "Notifications"
    }

    private static let redditOrange = Color(red: 1.0, green: 0.27, blue: 0.0)

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Button(action: { selectedTab = tab }) {
                        Text(tab.rawValue)
                            .font(.system(size: 11, weight: selectedTab == tab ? .semibold : .medium))
                            .foregroundStyle(selectedTab == tab ? Self.redditOrange : .secondary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 6)
                            .background(
                                selectedTab == tab
                                    ? Self.redditOrange.opacity(0.1)
                                    : Color.clear
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(.quaternary.opacity(0.15))

            Divider()

            switch selectedTab {
            case .channels:
                ChannelsTabView(notificationService: notificationService)
            case .general:
                GeneralTabView()
            case .notifications:
                NotificationsTabView()
            }
        }
        .frame(width: 500, height: 440)
    }
}
