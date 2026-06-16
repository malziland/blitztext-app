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
