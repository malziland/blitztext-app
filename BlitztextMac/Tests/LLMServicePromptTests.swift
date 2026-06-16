import XCTest
@testable import Blitztext
import BlitztextCore

final class LLMServicePromptTests: XCTestCase {
    func testRewriteModelRawValues() {
        // Guards DOC-001: the "$%&!" workflow requires gpt-4o, the others use gpt-4o-mini.
        XCTAssertEqual(RewriteModel.fastEdit.rawValue, "gpt-4o-mini")
        XCTAssertEqual(RewriteModel.rageMode.rawValue, "gpt-4o")
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

    func testCasualToneWordingDiffersFromFormal() {
        var formal = TextImprovementSettings(); formal.tone = .formal
        var casual = TextImprovementSettings(); casual.tone = .casual

        XCTAssertTrue(LLMService.buildSystemPrompt(settings: formal).contains("formellen"))
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

    func testEmojiPromptDensityWording() {
        XCTAssertTrue(LLMService.buildEmojiSystemPrompt(density: .wenig).contains("maximal 1-2"))
        XCTAssertTrue(LLMService.buildEmojiSystemPrompt(density: .mittel).contains("regelmaessig"))
        XCTAssertTrue(LLMService.buildEmojiSystemPrompt(density: .viel).contains("grosszuegig"))
    }
}
