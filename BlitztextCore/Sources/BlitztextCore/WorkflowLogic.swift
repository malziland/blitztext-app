import Foundation

/// The outcome of interpreting a raw transcript before it is shown to the user.
public enum TranscriptionOutcome: Equatable {
    case output(String)        // usable, cleaned transcript
    case rejected(String)      // no usable speech; message to display
}

/// Pure decision logic shared by the workflows, kept out of the @MainActor classes
/// so it can be unit-tested without recording or networking.
public enum WorkflowLogic {
    /// Custom vocabulary hints are only worth sending for recordings long enough to matter.
    public static func vocabularyHints(recordingDuration: TimeInterval, customTerms: [String]) -> [String] {
        recordingDuration >= 0.9 ? customTerms : []
    }

    /// Decides whether a transcript is usable or should be rejected as no-speech/artifact.
    public static func outcome(
        forTranscript text: String,
        recordingDuration: TimeInterval,
        maximumAudioLevel: Float,
        inputDeviceName: String?
    ) -> TranscriptionOutcome {
        let cleaned = TranscriptionQualityService.cleanedTranscript(text)
        if TranscriptionQualityService.isLikelyArtifact(cleaned, recordingDuration: recordingDuration) {
            return .rejected(
                TranscriptionQualityService.noSpeechMessage(
                    duration: recordingDuration,
                    maximumAudioLevel: maximumAudioLevel,
                    inputDeviceName: inputDeviceName
                )
            )
        }
        return .output(cleaned)
    }
}
