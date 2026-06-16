import Foundation
import AppKit
import Observation
import OSLog
import BlitztextCore

private let transcriptionLogger = Logger(subsystem: "app.blitztext.mac", category: "Transcription")

private func elapsedMilliseconds(since start: Date, until end: Date = Date()) -> Int {
    Int((end.timeIntervalSince(start) * 1000).rounded())
}

@Observable
@MainActor
final class TranscriptionWorkflow: Workflow {
    let type: WorkflowType
    var phase: WorkflowPhase = .idle {
        didSet { onPhaseChange?(phase) }
    }
    var onOutput: WorkflowOutputHandler?
    var onPhaseChange: WorkflowPhaseChangeHandler?

    private let recorder: any AudioRecording
    private let customTerms: [String]
    private let language: String
    private let backend: TranscriptionBackend
    private let localModelName: String
    private let audioInputDeviceID: String
    private let remoteTranscribe: (URL, [String], String) async throws -> String
    private let localTranscribe: (URL, String, String) async throws -> String
    private var transcriptionTask: Task<Void, Never>?

    init(
        type: WorkflowType = .transcription,
        customTerms: [String] = [],
        language: String = "de",
        backend: TranscriptionBackend = .remote,
        localModelName: String = LocalTranscriptionService.recommendedFastModelName,
        audioInputDeviceID: String = AudioInputDeviceService.systemDefaultDeviceID,
        recorder: (any AudioRecording)? = nil,
        remoteTranscribe: @escaping (URL, [String], String) async throws -> String = {
            try await TranscriptionService.transcribe(audioURL: $0, customTerms: $1, language: $2)
        },
        localTranscribe: @escaping (URL, String, String) async throws -> String = {
            try await LocalTranscriptionService.shared.transcribe(audioURL: $0, language: $1, modelName: $2)
        }
    ) {
        self.type = type
        self.customTerms = customTerms
        self.language = language
        self.backend = backend
        self.localModelName = localModelName
        self.audioInputDeviceID = audioInputDeviceID
        self.recorder = recorder ?? AudioRecorder()
        self.remoteTranscribe = remoteTranscribe
        self.localTranscribe = localTranscribe
    }

    func start() {
        phase = .running("Aufnahme läuft ...")
        recorder.startRecording(audioInputDeviceID: audioInputDeviceID)

        if let error = recorder.errorMessage {
            phase = .error(error)
        }
    }

    func stop() {
        if recorder.isRecording {
            phase = .running("Aufnahme wird verarbeitet ...")
            Task { [weak self] in
                await self?.finishRecording()
            }
        } else {
            transcriptionTask?.cancel()
            phase = .idle
        }
    }

    func reset() {
        transcriptionTask?.cancel()
        if recorder.isRecording {
            recorder.cancelRecording()
        }
        recorder.discardRecording()
        phase = .idle
    }

    var isRecording: Bool { recorder.isRecording }
    var audioLevel: Float { recorder.audioLevel }

    private func finishRecording() async {
        await recorder.stopRecording()

        if let error = recorder.errorMessage {
            phase = .error(error)
            return
        }

        if let message = TranscriptionQualityService.shortRecordingMessage(duration: recorder.lastRecordingDuration) {
            recorder.discardRecording()
            phase = .error(message)
            return
        }

        transcribe()
    }

    private func transcribe() {
        guard let url = recorder.recordingURL else {
            phase = .error("Keine Aufnahme vorhanden.")
            return
        }

        phase = .running(backend == .local ? "Wird lokal transkribiert ..." : "Wird transkribiert ...")
        let recordingDuration = recorder.lastRecordingDuration
        let maximumAudioLevel = recorder.maximumAudioLevel
        let inputDeviceName = recorder.inputDeviceName
        let vocabularyHints = WorkflowLogic.vocabularyHints(recordingDuration: recordingDuration, customTerms: customTerms)
        let requestLanguage = language
        let stopTime = Date()

        transcriptionTask = Task(priority: .userInitiated) {
            defer {
                try? FileManager.default.removeItem(at: url)
            }

            let requestStart = Date()
            do {
                let text: String
                switch backend {
                case .remote:
                    text = try await remoteTranscribe(url, vocabularyHints, requestLanguage)
                case .local:
                    text = try await localTranscribe(url, requestLanguage, localModelName)
                }
                try Task.checkCancellation()

                let responseReceivedAt = Date()
                switch WorkflowLogic.outcome(
                    forTranscript: text,
                    recordingDuration: recordingDuration,
                    maximumAudioLevel: maximumAudioLevel,
                    inputDeviceName: inputDeviceName
                ) {
                case .rejected(let message):
                    transcriptionLogger.info(
                        "Transcription rejected short artifact after \(elapsedMilliseconds(since: stopTime)) ms"
                    )
                    phase = .error(message)
                    return
                case .output(let cleaned):
                    transcriptionLogger.info(
                        "Transcription ready in \(elapsedMilliseconds(since: stopTime, until: responseReceivedAt)) ms (request \(elapsedMilliseconds(since: requestStart, until: responseReceivedAt)) ms)"
                    )
                    phase = .done(cleaned)
                    onOutput?(cleaned)
                }
            } catch {
                transcriptionLogger.error(
                    "Transcription failed after \(elapsedMilliseconds(since: stopTime)) ms: \(error.localizedDescription, privacy: .private)"
                )
                phase = .error(error.localizedDescription)
            }
        }
    }
}
