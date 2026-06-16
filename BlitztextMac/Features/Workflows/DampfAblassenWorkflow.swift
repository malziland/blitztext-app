import Foundation
import AppKit
import Observation
import BlitztextCore

@Observable
@MainActor
final class DampfAblassenWorkflow: Workflow {
    let type = WorkflowType.dampfAblassen
    var phase: WorkflowPhase = .idle {
        didSet { onPhaseChange?(phase) }
    }
    var onOutput: WorkflowOutputHandler?
    var onPhaseChange: WorkflowPhaseChangeHandler?

    private let recorder: any AudioRecording
    private let settings: DampfAblassenSettings
    private let customTerms: [String]
    private let language: String
    private let audioInputDeviceID: String
    private let transcribe: (URL, [String], String) async throws -> String
    private let rewrite: (String) async throws -> String
    private var processingTask: Task<Void, Never>?

    init(
        settings: DampfAblassenSettings,
        customTerms: [String] = [],
        language: String = "de",
        audioInputDeviceID: String = AudioInputDeviceService.systemDefaultDeviceID,
        recorder: (any AudioRecording)? = nil,
        transcribe: @escaping (URL, [String], String) async throws -> String = {
            try await TranscriptionService.transcribe(audioURL: $0, customTerms: $1, language: $2)
        },
        rewrite: ((String) async throws -> String)? = nil
    ) {
        self.settings = settings
        self.customTerms = customTerms
        self.language = language
        self.audioInputDeviceID = audioInputDeviceID
        self.recorder = recorder ?? AudioRecorder()
        self.transcribe = transcribe
        self.rewrite = rewrite ?? { [settings] in try await LLMService.dampfAblassen(text: $0, systemPrompt: settings.systemPrompt) }
    }

    // MARK: - Recording State

    var isRecording: Bool { recorder.isRecording }
    var audioLevel: Float { recorder.audioLevel }

    // MARK: - Workflow Protocol

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
            processingTask?.cancel()
            phase = .idle
        }
    }

    func reset() {
        processingTask?.cancel()
        if recorder.isRecording {
            recorder.cancelRecording()
        }
        recorder.discardRecording()
        phase = .idle
    }

    // MARK: - Two-Phase Processing: Whisper -> GPT Rage Mode

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

        processRecording()
    }

    private func processRecording() {
        guard let url = recorder.recordingURL else {
            phase = .error("Keine Aufnahme vorhanden.")
            return
        }

        phase = .running("Wird transkribiert ...")
        let recordingDuration = recorder.lastRecordingDuration
        let maximumAudioLevel = recorder.maximumAudioLevel
        let inputDeviceName = recorder.inputDeviceName
        let vocabularyHints = WorkflowLogic.vocabularyHints(recordingDuration: recordingDuration, customTerms: customTerms)

        processingTask = Task {
            defer {
                try? FileManager.default.removeItem(at: url)
            }

            do {
                // Phase 1: Whisper transcription
                let rawText = try await transcribe(url, vocabularyHints, language)
                let cleanedRawText = TranscriptionQualityService.cleanedTranscript(rawText)
                guard !TranscriptionQualityService.isLikelyArtifact(cleanedRawText, recordingDuration: recordingDuration) else {
                    phase = .error(
                        TranscriptionQualityService.noSpeechMessage(
                            duration: recordingDuration,
                            maximumAudioLevel: maximumAudioLevel,
                            inputDeviceName: inputDeviceName
                        )
                    )
                    return
                }

                if Task.isCancelled { return }

                // Phase 2: GPT dampf ablassen
                phase = .running("Wird umformuliert ...")

                let answer = try await rewrite(cleanedRawText)
                let cleanedAnswer = TranscriptionQualityService.cleanedTranscript(answer)
                guard cleanedAnswer != "KEINE_AUFNAHME_ERKANNT" else {
                    phase = .error(
                        TranscriptionQualityService.noSpeechMessage(
                            duration: recordingDuration,
                            maximumAudioLevel: maximumAudioLevel,
                            inputDeviceName: inputDeviceName
                        )
                    )
                    return
                }
                phase = .done(cleanedAnswer)
                onOutput?(cleanedAnswer)
            } catch {
                phase = .error(error.localizedDescription)
            }
        }
    }
}
