import Foundation

// MARK: - Workflow Types

public enum WorkflowType: String, CaseIterable, Identifiable, Codable {
    case transcription
    case localTranscription
    case textImprover

    public var id: String { rawValue }

    public static var mainMenuCases: [WorkflowType] {
        allCases.filter { $0 != .localTranscription }
    }

    public var displayName: String {
        switch self {
        case .transcription: return "Blitztext"
        case .localTranscription: return "Blitztext Lokal"
        case .textImprover: return "Blitztext+"
        }
    }

    public var icon: String {
        switch self {
        case .transcription: return "mic.fill"
        case .localTranscription: return "lock.shield.fill"
        case .textImprover: return "text.badge.checkmark"
        }
    }

    public var subtitle: String {
        switch self {
        case .transcription: return "Sprache rein. Text raus."
        case .localTranscription: return "Nur lokal. Kein Server."
        case .textImprover: return "Geschrieben sprechen."
        }
    }

    public var hotkeyLabel: String {
        switch self {
        case .transcription: return "fn"
        case .localTranscription: return "fn + Shift + Ctrl"
        case .textImprover: return "fn + Control"
        }
    }

    public var accentColor: String {
        switch self {
        case .transcription: return "blue"
        case .localTranscription: return "green"
        case .textImprover: return "purple"
        }
    }
}

// MARK: - Workflow State

public enum WorkflowPhase: Equatable {
    case idle
    case running(String)
    case done(String)
    case error(String)

    public var isActive: Bool {
        switch self {
        case .idle: return false
        default: return true
        }
    }
}
