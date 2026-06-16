import Foundation

// MARK: - Hotkey Mode

public enum HotkeyMode: String, Codable, CaseIterable, Identifiable {
    case hold    // Tasten halten = aufnehmen, loslassen = stoppen
    case toggle  // Einmal drücken = starten, nochmal/Escape = stoppen

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .hold: return "Halten"
        case .toggle: return "Drücken"
        }
    }

    public var description: String {
        switch self {
        case .hold: return "Tasten halten zum Aufnehmen, loslassen zum Stoppen"
        case .toggle: return "Einmal drücken zum Starten, nochmal oder Escape zum Stoppen"
        }
    }
}

// MARK: - Transcription Backend

public enum TranscriptionBackend: String, Codable {
    case remote
    case local
}

// MARK: - Workflow Settings

public struct TranscriptionSettings: Codable {
    public var language: String = "de"

    public init(language: String = "de") {
        self.language = language
    }
}

public struct DampfAblassenSettings: Codable {
    public var systemPrompt: String = "Du erhältst ein emotional gesprochenes Transkript. Erkenne zuerst das eigentliche Ziel, Anliegen und den wahren Frust der Person. Formuliere daraus eine klare, respektvolle und wirksame Nachricht, mit der die Person ihr Ziel eher erreicht. Bewahre relevante Fakten, konkrete Probleme, Grenzen, Erwartungen und die nötige Dringlichkeit. Entferne Beleidigungen, Drohungen, Sarkasmus, Unterstellungen und unnötige Eskalation. Wenn mehrere Vorwürfe genannt werden, verdichte sie auf die entscheidenden Kernpunkte. Der Ton soll ruhig, menschlich, bestimmt und lösungsorientiert sein. Gib NUR die fertige Nachricht zurück."
    public var customName: String = ""

    public init() {}
}

public struct EmojiTextSettings: Codable {
    public var emojiDensity: EmojiDensity = .mittel
    public var customName: String = ""

    public init() {}

    public enum EmojiDensity: String, Codable, CaseIterable, Identifiable {
        case wenig
        case mittel
        case viel

        public var id: String { rawValue }

        public var displayName: String {
            switch self {
            case .wenig: return "Wenig"
            case .mittel: return "Mittel"
            case .viel: return "Viel"
            }
        }
    }
}

public struct TextImprovementSettings: Codable {
    public var systemPrompt: String = ""
    public var customTerms: [String] = []
    public var context: String = ""
    public var tone: TextTone = .neutral
    public var customName: String = ""

    public init() {}

    public enum TextTone: String, Codable, CaseIterable, Identifiable {
        case formal
        case neutral
        case casual

        public var id: String { rawValue }

        public var displayName: String {
            switch self {
            case .formal: return "Formell"
            case .neutral: return "Neutral"
            case .casual: return "Locker"
            }
        }
    }
}

// MARK: - Defaults

/// Default values shared by the core and the platform apps (single source of truth).
public enum BlitztextDefaults {
    public static let recommendedFastWhisperModelName = "openai_whisper-small_216MB"
    public static let systemDefaultAudioDeviceID = "__system_default__"
}

// MARK: - App Settings

public struct AppSettings: Codable {
    public var hotkeyMode: HotkeyMode = .toggle
    public var hasSeenOnboarding: Bool = false
    public var secureLocalModeEnabled: Bool = false
    public var selectedLocalTranscriptionModelName: String = BlitztextDefaults.recommendedFastWhisperModelName
    public var hasAutoSelectedFastLocalModel: Bool = false
    public var selectedAudioInputDeviceID: String = BlitztextDefaults.systemDefaultAudioDeviceID

    public init(
        hotkeyMode: HotkeyMode = .toggle,
        hasSeenOnboarding: Bool = false,
        secureLocalModeEnabled: Bool = false,
        selectedLocalTranscriptionModelName: String = BlitztextDefaults.recommendedFastWhisperModelName,
        hasAutoSelectedFastLocalModel: Bool = false,
        selectedAudioInputDeviceID: String = BlitztextDefaults.systemDefaultAudioDeviceID
    ) {
        self.hotkeyMode = hotkeyMode
        self.hasSeenOnboarding = hasSeenOnboarding
        self.secureLocalModeEnabled = secureLocalModeEnabled
        self.selectedLocalTranscriptionModelName = selectedLocalTranscriptionModelName
        self.hasAutoSelectedFastLocalModel = hasAutoSelectedFastLocalModel
        self.selectedAudioInputDeviceID = selectedAudioInputDeviceID
    }

    enum CodingKeys: String, CodingKey {
        case hotkeyMode
        case hasSeenOnboarding
        case secureLocalModeEnabled
        case selectedLocalTranscriptionModelName
        case hasAutoSelectedFastLocalModel
        case selectedAudioInputDeviceID
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hotkeyMode = try container.decodeIfPresent(HotkeyMode.self, forKey: .hotkeyMode) ?? .toggle
        hasSeenOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasSeenOnboarding) ?? false
        secureLocalModeEnabled = try container.decodeIfPresent(Bool.self, forKey: .secureLocalModeEnabled) ?? false
        selectedLocalTranscriptionModelName = try container.decodeIfPresent(
            String.self,
            forKey: .selectedLocalTranscriptionModelName
        ) ?? BlitztextDefaults.recommendedFastWhisperModelName
        hasAutoSelectedFastLocalModel = try container.decodeIfPresent(
            Bool.self,
            forKey: .hasAutoSelectedFastLocalModel
        ) ?? false
        selectedAudioInputDeviceID = try container.decodeIfPresent(
            String.self,
            forKey: .selectedAudioInputDeviceID
        ) ?? BlitztextDefaults.systemDefaultAudioDeviceID
    }
}
