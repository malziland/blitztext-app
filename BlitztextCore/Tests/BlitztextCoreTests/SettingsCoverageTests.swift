import XCTest
import BlitztextCore

final class SettingsCoverageTests: XCTestCase {
    func testTextImprovementRoundTrip() throws {
        var settings = TextImprovementSettings()
        settings.customName = "Y"
        settings.tone = .casual

        let decoded = try JSONDecoder().decode(
            TextImprovementSettings.self,
            from: try JSONEncoder().encode(settings)
        )

        XCTAssertEqual(decoded.customName, "Y")
        XCTAssertEqual(decoded.tone, .casual)
    }

    func testAllEnumDisplayNamesAndIds() {
        for tone in TextImprovementSettings.TextTone.allCases {
            XCTAssertFalse(tone.displayName.isEmpty)
            XCTAssertEqual(tone.id, tone.rawValue)
        }
        for mode in HotkeyMode.allCases {
            XCTAssertFalse(mode.displayName.isEmpty)
            XCTAssertFalse(mode.description.isEmpty)
            XCTAssertEqual(mode.id, mode.rawValue)
        }
        for type in WorkflowType.allCases {
            XCTAssertEqual(type.id, type.rawValue)
        }
    }

    func testTextImprovementDecodesTone() throws {
        var settings = TextImprovementSettings()
        settings.tone = .formal
        let decoded = try JSONDecoder().decode(TextImprovementSettings.self, from: try JSONEncoder().encode(settings))
        XCTAssertEqual(decoded.tone, .formal)
    }
}
