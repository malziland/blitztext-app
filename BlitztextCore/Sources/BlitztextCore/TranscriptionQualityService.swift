import Foundation

public enum TranscriptionQualityService {
    public static let minimumRecordingDuration: TimeInterval = 0.8

    public static func shortRecordingMessage(duration: TimeInterval) -> String? {
        if duration < minimumRecordingDuration {
            return "Aufnahme zu kurz (\(formattedDuration(duration)) s). Bitte etwas laenger sprechen."
        }

        return nil
    }

    public static func noSpeechMessage(duration: TimeInterval, maximumAudioLevel: Float, inputDeviceName: String?) -> String {
        let deviceText = inputDeviceName.map { " ueber \"\($0)\"" } ?? ""
        return "Keine verwertbare Sprache erkannt\(deviceText). Dauer \(formattedDuration(duration)) s, Pegel \(formattedLevel(maximumAudioLevel))."
    }

    public static func cleanedTranscript(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func isLikelyArtifact(_ text: String, recordingDuration: TimeInterval) -> Bool {
        let cleaned = cleanedTranscript(text)
        guard !cleaned.isEmpty else { return true }

        let words = cleaned.split { $0.isWhitespace || $0.isNewline }
        let letters = cleaned.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count
        let normalized = cleaned
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: ".", with: "")

        if letters == 0 {
            return true
        }

        if normalized.contains("untertitelderamaracommunity")
            || normalized.contains("untertitelvonamaracommunity")
            || normalized.contains("untertitelderamaraorgcommunity")
            || normalized.contains("subtitlesbyamara")
            || normalized.contains("amaraorgcommunity") {
            return true
        }

        if recordingDuration < 0.55 && (words.count >= 5 || cleaned.count >= 32) {
            return true
        }

        if recordingDuration < 0.8 && cleaned.count >= 56 {
            return true
        }

        return false
    }

    private static func formattedDuration(_ duration: TimeInterval) -> String {
        String(format: "%.1f", duration)
    }

    private static func formattedLevel(_ level: Float) -> String {
        String(format: "%.2f", level)
    }
}
