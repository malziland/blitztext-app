import XCTest
import BlitztextCore

final class AppLogicTests: XCTestCase {
    // MARK: - KeyMasking

    func testKeyMaskingEmpty() {
        XCTAssertEqual(KeyMasking.masked(""), "")
    }

    func testKeyMaskingShortReturnsBulletsOnly() {
        XCTAssertEqual(KeyMasking.masked("sk-123"), String(repeating: "\u{2022}", count: 8))
    }

    func testKeyMaskingLongShowsFourCharPrefix() {
        let masked = KeyMasking.masked("sk-abcdefghijklmnop")
        XCTAssertTrue(masked.hasPrefix("sk-a "))
        XCTAssertTrue(masked.contains("\u{2022}"))
    }

    // MARK: - WorkflowAvailability

    func testRemoteTranscriptionNeedsKey() {
        XCTAssertTrue(WorkflowAvailability.isAvailable(.transcription, secureLocalModeEnabled: false, remoteKeyConfigured: true, localModelInstalled: false))
        XCTAssertFalse(WorkflowAvailability.isAvailable(.transcription, secureLocalModeEnabled: false, remoteKeyConfigured: false, localModelInstalled: true))
    }

    func testLocalTranscriptionNeedsModel() {
        XCTAssertTrue(WorkflowAvailability.isAvailable(.transcription, secureLocalModeEnabled: true, remoteKeyConfigured: false, localModelInstalled: true))
        XCTAssertFalse(WorkflowAvailability.isAvailable(.transcription, secureLocalModeEnabled: true, remoteKeyConfigured: true, localModelInstalled: false))
        XCTAssertTrue(WorkflowAvailability.isAvailable(.localTranscription, secureLocalModeEnabled: false, remoteKeyConfigured: false, localModelInstalled: true))
        XCTAssertFalse(WorkflowAvailability.isAvailable(.localTranscription, secureLocalModeEnabled: false, remoteKeyConfigured: true, localModelInstalled: false))
    }

    func testRewriteWorkflowsRequireKeyAndPauseInLocalMode() {
        for type in [WorkflowType.textImprover] {
            XCTAssertTrue(WorkflowAvailability.isAvailable(type, secureLocalModeEnabled: false, remoteKeyConfigured: true, localModelInstalled: true))
            XCTAssertFalse(WorkflowAvailability.isAvailable(type, secureLocalModeEnabled: true, remoteKeyConfigured: true, localModelInstalled: true))
            XCTAssertFalse(WorkflowAvailability.isAvailable(type, secureLocalModeEnabled: false, remoteKeyConfigured: false, localModelInstalled: true))
        }
    }

    // MARK: - PasteRetry

    func testPasteRetryDelayTiers() {
        XCTAssertEqual(PasteRetry.delay(attemptsRemaining: 22), 0.015, accuracy: 0.0001)
        XCTAssertEqual(PasteRetry.delay(attemptsRemaining: 16), 0.015, accuracy: 0.0001)
        XCTAssertEqual(PasteRetry.delay(attemptsRemaining: 15), 0.025, accuracy: 0.0001)
        XCTAssertEqual(PasteRetry.delay(attemptsRemaining: 8), 0.025, accuracy: 0.0001)
        XCTAssertEqual(PasteRetry.delay(attemptsRemaining: 7), 0.04, accuracy: 0.0001)
        XCTAssertEqual(PasteRetry.delay(attemptsRemaining: 1), 0.04, accuracy: 0.0001)
        XCTAssertEqual(PasteRetry.initialAttempts, 22)
    }
}
