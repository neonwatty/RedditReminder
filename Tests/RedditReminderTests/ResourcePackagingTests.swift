import Foundation
import Testing

@Test func peakTimesResourceIsPackagedInAppBundle() {
    let url = Bundle.main.url(forResource: "peak-times", withExtension: "json")
    #expect(url != nil)
}
