import XCTest
import BlitztextCore

final class SettingsCoverageTests: XCTestCase {
    func testDampfAndEmojiRoundTrips() throws {
        var dampf = DampfAblassenSettings()
        dampf.customName = "X"
        let dampfDecoded = try JSONDecoder().decode(DampfAblassenSettings.self, from: try JSONEncoder().encode(dampf))
        XCTAssertEqual(dampfDecoded.customName, "X")
        XCTAssertFalse(dampfDecoded.systemPrompt.isEmpty)

        var emoji = EmojiTextSettings()
        emoji.emojiDensity = .wenig
        emoji.customName = "Y"
        let emojiDecoded = try JSONDecoder().decode(EmojiTextSettings.self, from: try JSONEncoder().encode(emoji))
        XCTAssertEqual(emojiDecoded.emojiDensity, .wenig)
        XCTAssertEqual(emojiDecoded.customName, "Y")
    }

    func testAllEnumDisplayNamesAndIds() {
        for density in EmojiTextSettings.EmojiDensity.allCases {
            XCTAssertFalse(density.displayName.isEmpty)
            XCTAssertEqual(density.id, density.rawValue)
        }
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
