import Testing
import Foundation
@testable import RedditReminder

@Test func channelsExistsInAllCases() {
    #expect(SidebarState.allCases.contains(.channels))
}

@Test func channelsWidthIs320() {
    #expect(SidebarConstants.width(for: .channels) == 320)
}

@Test func channelsHasHeight() {
    let h = SidebarConstants.height(for: .channels, screenHeight: 800)
    #expect(h == 800 * 0.85)
}
