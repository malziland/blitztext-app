import Foundation

/// The on-disk container for all persisted settings. Optional members keep older
/// settings files (written before a field existed) decodable.
public struct SettingsContainer: Codable {
    public var app: AppSettings?
    public var transcription: TranscriptionSettings
    public var textImprovement: TextImprovementSettings
    public var dampfAblassen: DampfAblassenSettings?
    public var emojiText: EmojiTextSettings?

    public init(
        app: AppSettings?,
        transcription: TranscriptionSettings,
        textImprovement: TextImprovementSettings,
        dampfAblassen: DampfAblassenSettings?,
        emojiText: EmojiTextSettings?
    ) {
        self.app = app
        self.transcription = transcription
        self.textImprovement = textImprovement
        self.dampfAblassen = dampfAblassen
        self.emojiText = emojiText
    }
}
