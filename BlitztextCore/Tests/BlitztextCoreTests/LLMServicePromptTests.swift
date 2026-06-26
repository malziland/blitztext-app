import XCTest
import BlitztextCore

final class LLMServicePromptTests: XCTestCase {
    func testRewriteModelRawValue() {
        XCTAssertEqual(RewriteModel.fastEdit.rawValue, "gpt-4o-mini")
    }

    func testDefaultImprovementPromptIncludesToneTermsAndContext() {
        var settings = TextImprovementSettings()
        settings.tone = .formal
        settings.customTerms = ["malziland", "Blitztext"]
        settings.context = "Kundensupport"

        let prompt = LLMService.buildSystemPrompt(settings: settings)

        XCTAssertTrue(prompt.contains("formellen"))
        XCTAssertTrue(prompt.contains("malziland"))
        XCTAssertTrue(prompt.contains("Blitztext"))
        XCTAssertTrue(prompt.contains("Kundensupport"))
    }

    func testNeutralAndCasualToneWordingDiffer() {
        var neutral = TextImprovementSettings(); neutral.tone = .neutral
        var casual = TextImprovementSettings(); casual.tone = .casual

        XCTAssertTrue(LLMService.buildSystemPrompt(settings: neutral).contains("neutralen"))
        XCTAssertTrue(LLMService.buildSystemPrompt(settings: casual).contains("lockeren"))
    }

    func testCustomSystemPromptIsUsedAndTermsAppended() {
        var settings = TextImprovementSettings()
        settings.systemPrompt = "Mein eigener Prompt."
        settings.customTerms = ["Begriff"]

        let prompt = LLMService.buildSystemPrompt(settings: settings)

        XCTAssertTrue(prompt.hasPrefix("Mein eigener Prompt."))
        XCTAssertTrue(prompt.contains("Begriff"))
    }

    func testFormattingPromptForbidsRewritingAndAppendsTerms() {
        let prompt = LLMService.buildFormattingPrompt(customTerms: ["Blitztext", "malziland"])

        XCTAssertTrue(prompt.contains("Aendere NICHT den Wortlaut"))
        XCTAssertTrue(prompt.contains("KEINE Woerter hinzu"))
        XCTAssertTrue(prompt.contains("Blitztext"))
        XCTAssertTrue(prompt.contains("malziland"))
    }

    func testFormattingPromptWithoutTermsHasNoTermsLine() {
        let prompt = LLMService.buildFormattingPrompt(customTerms: [])

        XCTAssertFalse(prompt.contains("Eigennamen und Fachbegriffe exakt"))
    }

}
