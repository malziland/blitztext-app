import XCTest
import BlitztextCore

final class AudioMeteringTests: XCTestCase {
    func testNormalizedLevelMapsRange() {
        XCTAssertEqual(AudioMetering.normalizedLevel(powerDecibels: -50), 0, accuracy: 0.0001)
        XCTAssertEqual(AudioMetering.normalizedLevel(powerDecibels: -25), 0.5, accuracy: 0.0001)
        XCTAssertEqual(AudioMetering.normalizedLevel(powerDecibels: 0), 1, accuracy: 0.0001)
    }

    func testNormalizedLevelClampsOutOfRange() {
        XCTAssertEqual(AudioMetering.normalizedLevel(powerDecibels: -160), 0, accuracy: 0.0001)
        XCTAssertEqual(AudioMetering.normalizedLevel(powerDecibels: 10), 1, accuracy: 0.0001)
    }
}
