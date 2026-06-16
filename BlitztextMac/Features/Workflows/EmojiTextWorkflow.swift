import Foundation
import AppKit
import Observation
import BlitztextCore

@Observable
@MainActor
final class EmojiTextWorkflow: Workflow {
    let type = WorkflowType.emojiText
    var phase: WorkflowPhase = .idle {
        didSet { onPhaseChange?(phase) }
    }
    var onOutput: WorkflowOutputHandler?
    var onPhaseChange: WorkflowPhaseChangeHandler?

    private let recorder = AudioRecorder()
    private let settings: EmojiTextSettings
    private let customTerms: [String]
    private let language: String
    private let audioInputDeviceID: String
    private var processingTask: Task<Void, Never>?

    init(
        settings: EmojiTextSettings,
        customTerms: [String] = [],
        language: String = "de",
        audioInputDeviceID: String = AudioInputDeviceService.systemDefaultDeviceID
    ) {
        self.settings = settings
        self.customTerms = customTerms
        self.language = language
        self.audioInputDeviceID = audioInputDeviceID
    }

    // MARK: - Recording State

    var isRecording: Bool { recorder.isRecording }
    var audioLevel: Float { recorder.audioLevel }

    // MARK: - Workflow Protocol

    func start() {
        phase = .running("Aufnahme l\u{00E4}uft ...")
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

    // MARK: - Two-Phase Processing: Whisper -> Emoji

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
                let rawText = try await TranscriptionService.transcribe(
                    audioURL: url,
                    customTerms: vocabularyHints,
                    language: language
                )
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

                // Phase 2: Add emojis
                phase = .running("Emojis werden eingef\u{00FC}gt ...")

                let result = try await LLMService.addEmojis(
                    text: cleanedRawText,
                    settings: settings
                )
                let cleanedResult = TranscriptionQualityService.cleanedTranscript(result)
                guard cleanedResult != "KEINE_AUFNAHME_ERKANNT" else {
                    phase = .error(
                        TranscriptionQualityService.noSpeechMessage(
                            duration: recordingDuration,
                            maximumAudioLevel: maximumAudioLevel,
                            inputDeviceName: inputDeviceName
                        )
                    )
                    return
                }
                phase = .done(cleanedResult)
                onOutput?(cleanedResult)
            } catch {
                phase = .error(error.localizedDescription)
            }
        }
    }
}
