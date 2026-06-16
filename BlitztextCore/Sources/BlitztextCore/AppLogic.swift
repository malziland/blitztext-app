import Foundation

/// Masks a stored secret for display (e.g. an API key shown in settings).
public enum KeyMasking {
    public static func masked(_ value: String) -> String {
        guard !value.isEmpty else { return "" }
        let bullets = String(repeating: "\u{2022}", count: 8)
        if value.count > 8 {
            return String(value.prefix(4)) + " " + bullets
        }
        return bullets
    }
}

/// Rules deciding whether a workflow can run, given the current configuration.
public enum WorkflowAvailability {
    public static func isAvailable(
        _ type: WorkflowType,
        secureLocalModeEnabled: Bool,
        remoteKeyConfigured: Bool,
        localModelInstalled: Bool
    ) -> Bool {
        switch type {
        case .localTranscription:
            return localModelInstalled
        case .transcription:
            return secureLocalModeEnabled ? localModelInstalled : remoteKeyConfigured
        case .textImprover, .dampfAblassen, .emojiText:
            return !secureLocalModeEnabled && remoteKeyConfigured
        }
    }
}

/// Backoff schedule for the auto-paste retry loop.
public enum PasteRetry {
    public static let initialAttempts = 22

    public static func delay(attemptsRemaining: Int) -> TimeInterval {
        switch attemptsRemaining {
        case 16...:
            return 0.015
        case 8...15:
            return 0.025
        default:
            return 0.04
        }
    }
}
