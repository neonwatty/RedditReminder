import Testing
import Foundation
@testable import RedditReminder

@Test func glanceHeightIsFixed() {
    #expect(SidebarConstants.height(for: .glance, screenHeight: 800) == 240)
}

@Test func settingsHeightIsFixed() {
    #expect(SidebarConstants.height(for: .settings, screenHeight: 800) == 340)
}

@Test func browseHeightIsProportional() {
    #expect(SidebarConstants.height(for: .browse, screenHeight: 1000) == 850)
}

@Test func captureHeightIsProportional() {
    #expect(SidebarConstants.height(for: .capture, screenHeight: 1000) == 700)
}

@Test func stripHeightIsFullScreen() {
    #expect(SidebarConstants.height(for: .strip, screenHeight: 900) == 900)
}

@Test func allStatesHavePositiveHeight() {
    for state in SidebarState.allCases {
        #expect(SidebarConstants.height(for: state, screenHeight: 800) > 0)
    }
}

@Test func allStatesHavePositiveWidth() {
    for state in SidebarState.allCases {
        #expect(SidebarConstants.width(for: state) > 0)
    }
}
