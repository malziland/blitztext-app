import XCTest
import BlitztextCore
@testable import Blitztext

/// A fake recorder so the workflow orchestration can be driven without a real
/// microphone, AVFoundation, or network.
@MainActor
final class FakeRecorder: AudioRecording {
    var isRecording = false
    var recordingURL: URL?
    var errorMessage: String?
    var lastRecordingDuration: TimeInterval = 0
    var maximumAudioLevel: Float = 0
    var audioLevel: Float = 0
    var inputDeviceName: String?

    // Configured by tests:
    var urlOnStop: URL? = FileManager.default.temporaryDirectory
        .appendingPathComponent("blitztext-test-\(UUID().uuidString).m4a")
    var durationOnStop: TimeInterval = 2.0
    var errorOnStop: String?

    func startRecording(audioInputDeviceID: String?) {
        isRecording = true
        errorMessage = nil
    }

    func stopRecording() async {
        isRecording = false
        recordingURL = urlOnStop
        lastRecordingDuration = durationOnStop
        errorMessage = errorOnStop
    }

    func cancelRecording() { isRecording = false }
    func discardRecording() { recordingURL = nil }
}

@MainActor
final class WorkflowOrchestrationTests: XCTestCase {
    private func waitForTerminalPhase(_ workflow: any Workflow) async {
        let terminal = expectation(description: "terminal phase")
        terminal.assertForOverFulfill = false
        workflow.onPhaseChange = { phase in
            switch phase {
            case .done, .error: terminal.fulfill()
            default: break
            }
        }
        await fulfillment(of: [terminal], timeout: 5)
    }

    func testTranscriptionProducesOutput() async {
        let recorder = FakeRecorder()
        recorder.durationOnStop = 2.0
        var outputs: [String] = []
        let workflow = TranscriptionWorkflow(
            recorder: recorder,
            remoteTranscribe: { _, _, _ in "Hallo Welt" }
        )
        workflow.onOutput = { outputs.append($0) }

        workflow.start()
        workflow.stop()
        await waitForTerminalPhase(workflow)

        XCTAssertEqual(outputs, ["Hallo Welt"])
        XCTAssertEqual(workflow.phase, .done("Hallo Welt"))
    }

    func testTranscriptionRejectsArtifact() async {
        let recorder = FakeRecorder()
        recorder.durationOnStop = 2.0
        let workflow = TranscriptionWorkflow(
            recorder: recorder,
            remoteTranscribe: { _, _, _ in "Untertitel der Amara-Community" }
        )

        workflow.start()
        workflow.stop()
        await waitForTerminalPhase(workflow)

        guard case .error(let message) = workflow.phase else { return XCTFail("expected error, got \(workflow.phase)") }
        XCTAssertTrue(message.contains("Keine verwertbare Sprache"))
    }

    func testTooShortRecordingIsRejectedBeforeTranscription() async {
        let recorder = FakeRecorder()
        recorder.durationOnStop = 0.3
        var transcribeCalled = false
        let workflow = TranscriptionWorkflow(
            recorder: recorder,
            remoteTranscribe: { _, _, _ in transcribeCalled = true; return "x" }
        )

        workflow.start()
        workflow.stop()
        await waitForTerminalPhase(workflow)

        XCTAssertFalse(transcribeCalled)
        guard case .error(let message) = workflow.phase else { return XCTFail("expected error") }
        XCTAssertTrue(message.contains("zu kurz"))
    }

    func testRecorderErrorSurfaces() async {
        let recorder = FakeRecorder()
        recorder.errorOnStop = "Mikrofon nicht verfuegbar."
        let workflow = TranscriptionWorkflow(
            recorder: recorder,
            remoteTranscribe: { _, _, _ in "ignored" }
        )

        workflow.start()
        workflow.stop()
        await waitForTerminalPhase(workflow)

        XCTAssertEqual(workflow.phase, .error("Mikrofon nicht verfuegbar."))
    }

    func testRemoteFormattingPassIsAppliedWhenEnabled() async {
        let recorder = FakeRecorder()
        recorder.durationOnStop = 2.0
        var outputs: [String] = []
        let workflow = TranscriptionWorkflow(
            backend: .remote,
            formatTranscription: true,
            recorder: recorder,
            remoteTranscribe: { _, _, _ in "hallo welt das ist ein test" },
            formatRemote: { input in "formatiert: \(input)" }
        )
        workflow.onOutput = { outputs.append($0) }

        workflow.start()
        workflow.stop()
        await waitForTerminalPhase(workflow)

        XCTAssertEqual(outputs, ["formatiert: hallo welt das ist ein test"])
    }

    func testRemoteFormattingFallsBackToOfflineWhenPassFails() async {
        let recorder = FakeRecorder()
        recorder.durationOnStop = 2.0
        var outputs: [String] = []
        let workflow = TranscriptionWorkflow(
            backend: .remote,
            formatTranscription: true,
            recorder: recorder,
            remoteTranscribe: { _, _, _ in "hallo welt neue zeile zweite zeile" },
            formatRemote: { _ in throw LLMError.noContent }
        )
        workflow.onOutput = { outputs.append($0) }

        workflow.start()
        workflow.stop()
        await waitForTerminalPhase(workflow)

        // Offline fallback capitalizes and turns "neue zeile" into a line break.
        XCTAssertEqual(outputs, ["Hallo welt\nZweite zeile"])
    }

    func testLocalFormattingUsesOfflineFormatterWithoutNetwork() async {
        let recorder = FakeRecorder()
        recorder.durationOnStop = 2.0
        var outputs: [String] = []
        var formatRemoteCalled = false
        let workflow = TranscriptionWorkflow(
            type: .localTranscription,
            backend: .local,
            formatTranscription: true,
            recorder: recorder,
            localTranscribe: { _, _, _ in "erste zeile neuer absatz zweite zeile" },
            formatRemote: { input in formatRemoteCalled = true; return input }
        )
        workflow.onOutput = { outputs.append($0) }

        workflow.start()
        workflow.stop()
        await waitForTerminalPhase(workflow)

        XCTAssertFalse(formatRemoteCalled, "local mode must not call the online formatting pass")
        XCTAssertEqual(outputs, ["Erste zeile\n\nZweite zeile"])
    }

    func testShortTranscriptSkipsOnlineFormatting() async {
        let recorder = FakeRecorder()
        recorder.durationOnStop = 2.0
        var outputs: [String] = []
        var formatRemoteCalled = false
        let workflow = TranscriptionWorkflow(
            backend: .remote,
            formatTranscription: true,
            recorder: recorder,
            remoteTranscribe: { _, _, _ in "ja danke" },
            formatRemote: { input in formatRemoteCalled = true; return input }
        )
        workflow.onOutput = { outputs.append($0) }

        workflow.start()
        workflow.stop()
        await waitForTerminalPhase(workflow)

        XCTAssertFalse(formatRemoteCalled, "trivial utterances must not trigger a paid format call")
        XCTAssertEqual(outputs, ["Ja danke"])
    }

    func testImplausibleFormattingFallsBackToOffline() async {
        let recorder = FakeRecorder()
        recorder.durationOnStop = 2.0
        var outputs: [String] = []
        let workflow = TranscriptionWorkflow(
            backend: .remote,
            formatTranscription: true,
            recorder: recorder,
            remoteTranscribe: { _, _, _ in "hallo welt das ist ein test" },
            formatRemote: { _ in String(repeating: "zusatz ", count: 50) }
        )
        workflow.onOutput = { outputs.append($0) }

        workflow.start()
        workflow.stop()
        await waitForTerminalPhase(workflow)

        // The bloated response is rejected; the offline formatter is used instead.
        XCTAssertEqual(outputs, ["Hallo welt das ist ein test"])
    }

    func testFormattingDisabledKeepsRawTranscript() async {
        let recorder = FakeRecorder()
        recorder.durationOnStop = 2.0
        var outputs: [String] = []
        let workflow = TranscriptionWorkflow(
            backend: .remote,
            formatTranscription: false,
            recorder: recorder,
            remoteTranscribe: { _, _, _ in "hallo welt neue zeile" },
            formatRemote: { _ in "should not be used" }
        )
        workflow.onOutput = { outputs.append($0) }

        workflow.start()
        workflow.stop()
        await waitForTerminalPhase(workflow)

        XCTAssertEqual(outputs, ["hallo welt neue zeile"])
    }

    func testTextImprovementAppliesRewrite() async {
        let recorder = FakeRecorder()
        recorder.durationOnStop = 2.0
        var outputs: [String] = []
        let workflow = TextImprovementWorkflow(
            settings: TextImprovementSettings(),
            recorder: recorder,
            transcribe: { _, _, _ in "roh text" },
            rewrite: { input in "verbessert: \(input)" }
        )
        workflow.onOutput = { outputs.append($0) }

        workflow.start()
        workflow.stop()
        await waitForTerminalPhase(workflow)

        XCTAssertEqual(outputs, ["verbessert: roh text"])
        XCTAssertEqual(workflow.phase, .done("verbessert: roh text"))
    }
}
