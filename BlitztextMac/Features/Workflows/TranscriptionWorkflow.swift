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
    private let formatTranscription: Bool
    private let remoteTranscribe: (URL, [String], String) async throws -> String
    private let localTranscribe: (URL, String, String) async throws -> String
    private let formatRemote: (String) async throws -> String
    private var transcriptionTask: Task<Void, Never>?

    init(
        type: WorkflowType = .transcription,
        customTerms: [String] = [],
        language: String = "de",
        backend: TranscriptionBackend = .remote,
        localModelName: String = LocalTranscriptionService.recommendedFastModelName,
        audioInputDeviceID: String = AudioInputDeviceService.systemDefaultDeviceID,
        formatTranscription: Bool = false,
        recorder: (any AudioRecording)? = nil,
        remoteTranscribe: @escaping (URL, [String], String) async throws -> String = {
            try await TranscriptionService.transcribe(audioURL: $0, customTerms: $1, language: $2)
        },
        localTranscribe: @escaping (URL, String, String) async throws -> String = {
            try await LocalTranscriptionService.shared.transcribe(audioURL: $0, language: $1, modelName: $2)
        },
        formatRemote: ((String) async throws -> String)? = nil
    ) {
        self.type = type
        self.customTerms = customTerms
        self.language = language
        self.backend = backend
        self.localModelName = localModelName
        self.audioInputDeviceID = audioInputDeviceID
        self.formatTranscription = formatTranscription
        self.recorder = recorder ?? AudioRecorder()
        self.remoteTranscribe = remoteTranscribe
        self.localTranscribe = localTranscribe
        self.formatRemote = formatRemote ?? { [customTerms] in
            try await LLMService.format(text: $0, customTerms: customTerms)
        }
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
                    let finalText = await formattedOutput(cleaned)
                    try Task.checkCancellation()
                    phase = .done(finalText)
                    onOutput?(finalText)
                }
            } catch {
                transcriptionLogger.error(
                    "Transcription failed after \(elapsedMilliseconds(since: stopTime)) ms: \(error.localizedDescription, privacy: .private)"
                )
                phase = .error(error.localizedDescription)
            }
        }
    }

    /// Optionally improves the transcript's layout (capitalization, punctuation,
    /// paragraphs). Online it uses the LLM formatting pass; in secure local mode
    /// it stays on-device. If the online pass fails, it degrades to the offline
    /// formatter so the user never loses the dictation to a formatting error.
    private func formattedOutput(_ cleaned: String) async -> String {
        guard formatTranscription else { return cleaned }

        switch backend {
        case .local:
            return TranscriptFormatter.format(cleaned)
        case .remote:
            // Trivial utterances don't need a paid round-trip; the offline
            // formatter (capitalization) is enough.
            if TranscriptFormatter.isTrivialForOnlineFormatting(cleaned) {
                return TranscriptFormatter.format(cleaned)
            }

            phase = .running("Wird formatiert ...")
            do {
                let formatted = TranscriptionQualityService.cleanedTranscript(try await formatRemote(cleaned))
                guard TranscriptFormatter.isPlausibleReformatting(original: cleaned, formatted: formatted) else {
                    transcriptionLogger.error("Formatting pass returned implausible output, using offline fallback")
                    return TranscriptFormatter.format(cleaned)
                }
                return formatted
            } catch {
                transcriptionLogger.error("Formatting pass failed, using offline fallback: \(error.localizedDescription, privacy: .private)")
                return TranscriptFormatter.format(cleaned)
            }
        }
    }
}
