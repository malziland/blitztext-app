import XCTest
import BlitztextCore

final class SettingsContainerTests: XCTestCase {
    func testRoundTripPreservesAllSections() throws {
        var textImprovement = TextImprovementSettings()
        textImprovement.context = "C"

        let container = SettingsContainer(
            app: AppSettings(hasSeenOnboarding: true),
            transcription: TranscriptionSettings(language: "en"),
            textImprovement: textImprovement
        )

        let data = try JSONEncoder().encode(container)
        let decoded = try JSONDecoder().decode(SettingsContainer.self, from: data)

        XCTAssertEqual(decoded.app?.hasSeenOnboarding, true)
        XCTAssertEqual(decoded.transcription.language, "en")
        XCTAssertEqual(decoded.textImprovement.context, "C")
    }

    func testOptionalAppMemberToleratesOlderFiles() throws {
        // An older settings file written before the `app` section existed
        // (and one that still carries removed workflow sections, which are ignored).
        let json = Data("""
        {"transcription":{"language":"de"},"textImprovement":{"systemPrompt":"","customTerms":[],"context":"","tone":"neutral","customName":""},"dampfAblassen":{"systemPrompt":"x","customName":""}}
        """.utf8)

        let decoded = try JSONDecoder().decode(SettingsContainer.self, from: json)

        XCTAssertNil(decoded.app)
        XCTAssertEqual(decoded.transcription.language, "de")
    }
}
