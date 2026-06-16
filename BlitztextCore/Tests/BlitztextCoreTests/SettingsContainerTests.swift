import XCTest
import BlitztextCore

final class SettingsContainerTests: XCTestCase {
    func testRoundTripPreservesAllSections() throws {
        var textImprovement = TextImprovementSettings()
        textImprovement.context = "C"

        let container = SettingsContainer(
            app: AppSettings(hasSeenOnboarding: true),
            transcription: TranscriptionSettings(language: "en"),
            textImprovement: textImprovement,
            dampfAblassen: DampfAblassenSettings(),
            emojiText: EmojiTextSettings()
        )

        let data = try JSONEncoder().encode(container)
        let decoded = try JSONDecoder().decode(SettingsContainer.self, from: data)

        XCTAssertEqual(decoded.app?.hasSeenOnboarding, true)
        XCTAssertEqual(decoded.transcription.language, "en")
        XCTAssertEqual(decoded.textImprovement.context, "C")
        XCTAssertNotNil(decoded.dampfAblassen)
        XCTAssertNotNil(decoded.emojiText)
    }

    func testOptionalMembersTolerateOlderFiles() throws {
        // An older settings file written before app/dampfAblassen/emojiText existed.
        let json = Data("""
        {"transcription":{"language":"de"},"textImprovement":{"systemPrompt":"","customTerms":[],"context":"","tone":"neutral","customName":""}}
        """.utf8)

        let decoded = try JSONDecoder().decode(SettingsContainer.self, from: json)

        XCTAssertNil(decoded.app)
        XCTAssertNil(decoded.dampfAblassen)
        XCTAssertNil(decoded.emojiText)
        XCTAssertEqual(decoded.transcription.language, "de")
    }
}
