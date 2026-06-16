import XCTest
import BlitztextCore

final class SettingsAndKeychainTests: XCTestCase {
    func testKeychainKeyLabelAndRawValue() {
        XCTAssertEqual(KeychainKey.openAIAPIKey.rawValue, "openAIAPIKey")
        XCTAssertEqual(KeychainKey.openAIAPIKey.label, "OpenAI API Key")
        XCTAssertTrue(KeychainKey.allCases.contains(.openAIAPIKey))
    }

    func testTextImprovementSettingsRoundTrip() throws {
        var settings = TextImprovementSettings()
        settings.systemPrompt = "P"
        settings.customTerms = ["a", "b"]
        settings.context = "C"
        settings.tone = .casual
        settings.customName = "N"

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(TextImprovementSettings.self, from: data)

        XCTAssertEqual(decoded.systemPrompt, "P")
        XCTAssertEqual(decoded.customTerms, ["a", "b"])
        XCTAssertEqual(decoded.context, "C")
        XCTAssertEqual(decoded.tone, .casual)
        XCTAssertEqual(decoded.customName, "N")
    }

    func testDefaultsAndBackend() {
        XCTAssertEqual(EmojiTextSettings().emojiDensity, .mittel)
        XCTAssertEqual(TranscriptionSettings().language, "de")
        XCTAssertEqual(TranscriptionBackend.remote.rawValue, "remote")
        XCTAssertEqual(TranscriptionBackend.local.rawValue, "local")
    }

    func testEnumDisplayNames() {
        XCTAssertEqual(TextImprovementSettings.TextTone.formal.displayName, "Formell")
        XCTAssertEqual(TextImprovementSettings.TextTone.neutral.displayName, "Neutral")
        XCTAssertEqual(EmojiTextSettings.EmojiDensity.viel.displayName, "Viel")
        XCTAssertEqual(HotkeyMode.toggle.displayName, "Drücken")
        XCTAssertEqual(HotkeyMode.hold.displayName, "Halten")
    }

    func testHotkeyModeCodableRoundTrip() throws {
        for mode in HotkeyMode.allCases {
            let data = try JSONEncoder().encode(mode)
            XCTAssertEqual(try JSONDecoder().decode(HotkeyMode.self, from: data), mode)
        }
    }

    func testWorkflowTypePresentationProperties() {
        // Exercises the icon/subtitle/hotkeyLabel/accentColor branches.
        for type in WorkflowType.allCases {
            XCTAssertFalse(type.icon.isEmpty)
            XCTAssertFalse(type.subtitle.isEmpty)
            XCTAssertFalse(type.hotkeyLabel.isEmpty)
            XCTAssertFalse(type.accentColor.isEmpty)
        }
    }
}
