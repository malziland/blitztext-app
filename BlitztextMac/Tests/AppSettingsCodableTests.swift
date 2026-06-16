import XCTest
@testable import Blitztext
import BlitztextCore

final class AppSettingsCodableTests: XCTestCase {
    func testFullRoundTripPreservesValues() throws {
        let original = AppSettings(
            hotkeyMode: .hold,
            hasSeenOnboarding: true,
            secureLocalModeEnabled: true,
            selectedLocalTranscriptionModelName: "custom-model",
            hasAutoSelectedFastLocalModel: true,
            selectedAudioInputDeviceID: "device-42"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)

        XCTAssertEqual(decoded.hotkeyMode, original.hotkeyMode)
        XCTAssertTrue(decoded.hasSeenOnboarding)
        XCTAssertTrue(decoded.secureLocalModeEnabled)
        XCTAssertEqual(decoded.selectedLocalTranscriptionModelName, "custom-model")
        XCTAssertTrue(decoded.hasAutoSelectedFastLocalModel)
        XCTAssertEqual(decoded.selectedAudioInputDeviceID, "device-42")
    }

    func testPartialJSONFallsBackToDefaults() throws {
        // Omits hotkeyMode / secureLocalModeEnabled / hasAutoSelectedFastLocalModel to
        // characterize the decodeIfPresent defaults. Provides selectedAudioInputDeviceID
        // so decoding does not have to query the Core Audio system default.
        let json = Data("""
        {
          "hasSeenOnboarding": true,
          "selectedAudioInputDeviceID": "device-42",
          "selectedLocalTranscriptionModelName": "custom-model"
        }
        """.utf8)

        let decoded = try JSONDecoder().decode(AppSettings.self, from: json)

        XCTAssertEqual(decoded.hotkeyMode, .toggle)
        XCTAssertFalse(decoded.secureLocalModeEnabled)
        XCTAssertFalse(decoded.hasAutoSelectedFastLocalModel)
        XCTAssertTrue(decoded.hasSeenOnboarding)
        XCTAssertEqual(decoded.selectedAudioInputDeviceID, "device-42")
    }
}
