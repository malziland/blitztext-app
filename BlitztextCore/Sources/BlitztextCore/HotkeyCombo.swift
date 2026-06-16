import Foundation

/// Platform-agnostic representation of the relevant keyboard modifiers, so the
/// combo-to-workflow mapping can be unit-tested without AppKit.
public struct HotkeyModifiers: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let function = HotkeyModifiers(rawValue: 1 << 0)
    public static let shift    = HotkeyModifiers(rawValue: 1 << 1)
    public static let control  = HotkeyModifiers(rawValue: 1 << 2)
    public static let option   = HotkeyModifiers(rawValue: 1 << 3)
    public static let command  = HotkeyModifiers(rawValue: 1 << 4)
}

public enum HotkeyCombo {
    /// Maps a held modifier combination to the workflow it triggers.
    /// `fn` alone is handled separately by the service (delayed press) and returns nil here.
    /// Order matters: more specific combinations are checked first.
    public static func workflowType(for modifiers: HotkeyModifiers) -> WorkflowType? {
        if modifiers.contains([.function, .shift, .control]) { return .localTranscription }
        if modifiers.contains([.function, .shift]) { return .transcription }
        if modifiers.contains([.function, .control]) { return .textImprover }
        if modifiers.contains([.function, .option]) { return .dampfAblassen }
        if modifiers.contains([.function, .command]) { return .emojiText }
        return nil
    }
}
