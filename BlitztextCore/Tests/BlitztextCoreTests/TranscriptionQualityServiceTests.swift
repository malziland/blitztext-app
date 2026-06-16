import XCTest
import BlitztextCore

final class TranscriptionQualityServiceTests: XCTestCase {
    func testShortRecordingMessageBelowThreshold() {
        XCTAssertNotNil(TranscriptionQualityService.shortRecordingMessage(duration: 0.5))
    }

    func testShortRecordingMessageAtOrAboveThreshold() {
        XCTAssertNil(TranscriptionQualityService.shortRecordingMessage(duration: 0.8))
        XCTAssertNil(TranscriptionQualityService.shortRecordingMessage(duration: 1.5))
    }

    func testCleanedTranscriptTrimsWhitespace() {
        XCTAssertEqual(TranscriptionQualityService.cleanedTranscript("  hallo \n"), "hallo")
    }

    func testEmptyTranscriptIsArtifact() {
        XCTAssertTrue(TranscriptionQualityService.isLikelyArtifact("", recordingDuration: 2))
        XCTAssertTrue(TranscriptionQualityService.isLikelyArtifact("   \n ", recordingDuration: 2))
    }

    func testLetterlessTranscriptIsArtifact() {
        XCTAssertTrue(TranscriptionQualityService.isLikelyArtifact("123 456 -", recordingDuration: 2))
    }

    func testAmaraSubtitleArtifactsDetected() {
        XCTAssertTrue(TranscriptionQualityService.isLikelyArtifact("Untertitel der Amara-Community", recordingDuration: 2))
        XCTAssertTrue(TranscriptionQualityService.isLikelyArtifact("Untertitel der Amara.org-Community", recordingDuration: 2))
        XCTAssertTrue(TranscriptionQualityService.isLikelyArtifact("Subtitles by the Amara.org community", recordingDuration: 2))
    }

    func testNormalSpeechIsNotArtifact() {
        XCTAssertFalse(TranscriptionQualityService.isLikelyArtifact("Das ist ein ganz normaler Satz.", recordingDuration: 2))
        XCTAssertFalse(TranscriptionQualityService.isLikelyArtifact("Hallo Welt", recordingDuration: 0.7))
    }

    func testVeryShortRecordingWithManyWordsIsArtifact() {
        XCTAssertTrue(TranscriptionQualityService.isLikelyArtifact("ein zwei drei vier fuenf sechs", recordingDuration: 0.4))
    }

    func testSubSecondRecordingWithLongTextIsArtifact() {
        let longText = String(repeating: "wort ", count: 14) // > 56 characters
        XCTAssertTrue(TranscriptionQualityService.isLikelyArtifact(longText, recordingDuration: 0.7))
    }

    func testNoSpeechMessageMentionsDevice() {
        let message = TranscriptionQualityService.noSpeechMessage(
            duration: 1.0,
            maximumAudioLevel: 0.1,
            inputDeviceName: "MacBook Mikrofon"
        )
        XCTAssertTrue(message.contains("MacBook Mikrofon"))
    }
}
