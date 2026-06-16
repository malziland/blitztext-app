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
