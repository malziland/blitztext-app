import XCTest
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
        // Omits hotkeyMode / secureLocalModeEnabled / hasAutoSelectedFastLocalModel; provides
        // the device id so decoding does not depend on the system default.
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

    func testDefaultsComeFromBlitztextDefaults() {
        let settings = AppSettings()
        XCTAssertEqual(settings.selectedLocalTranscriptionModelName, BlitztextDefaults.recommendedFastWhisperModelName)
        XCTAssertEqual(settings.selectedAudioInputDeviceID, BlitztextDefaults.systemDefaultAudioDeviceID)
        XCTAssertEqual(settings.hotkeyMode, .toggle)
    }
}
