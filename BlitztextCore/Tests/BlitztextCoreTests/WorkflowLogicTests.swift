import XCTest
import BlitztextCore

final class WorkflowLogicTests: XCTestCase {
    func testVocabularyHintsGatedByDuration() {
        XCTAssertEqual(WorkflowLogic.vocabularyHints(recordingDuration: 1.0, customTerms: ["a", "b"]), ["a", "b"])
        XCTAssertEqual(WorkflowLogic.vocabularyHints(recordingDuration: 0.9, customTerms: ["a"]), ["a"])
        XCTAssertEqual(WorkflowLogic.vocabularyHints(recordingDuration: 0.5, customTerms: ["a"]), [])
    }

    func testOutcomeUsableTranscriptIsTrimmed() {
        let outcome = WorkflowLogic.outcome(
            forTranscript: "  Hallo Welt \n",
            recordingDuration: 2,
            maximumAudioLevel: 0.5,
            inputDeviceName: "Mic"
        )
        XCTAssertEqual(outcome, .output("Hallo Welt"))
    }

    func testOutcomeRejectsArtifactWithDeviceMessage() {
        let outcome = WorkflowLogic.outcome(
            forTranscript: "Untertitel der Amara-Community",
            recordingDuration: 2,
            maximumAudioLevel: 0.1,
            inputDeviceName: "MacBook Mikrofon"
        )
        guard case .rejected(let message) = outcome else { return XCTFail("expected rejected") }
        XCTAssertTrue(message.contains("Keine verwertbare Sprache"))
        XCTAssertTrue(message.contains("MacBook Mikrofon"))
    }

    func testOutcomeRejectsEmpty() {
        let outcome = WorkflowLogic.outcome(
            forTranscript: "   ",
            recordingDuration: 2,
            maximumAudioLevel: 0,
            inputDeviceName: nil
        )
        guard case .rejected = outcome else { return XCTFail("expected rejected") }
    }
}
