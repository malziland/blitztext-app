import Cocoa
import Observation
import BlitztextCore

enum HotkeyEvent {
    case down(WorkflowType)  // Keys pressed
    case up(WorkflowType)    // Keys released (for hold mode)
    case cancel              // Escape pressed
}

@Observable
@MainActor
final class HotkeyService {
    private static let functionOnlyDelayNanoseconds: UInt64 = 90_000_000
    private static let relevantModifierMask: NSEvent.ModifierFlags = [
        .function,
        .shift,
        .control,
        .option,
        .command
    ]

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var keyMonitor: Any?
    private var activeCombo: WorkflowType?  // Which combo is currently held
    private var pendingFunctionOnlyTask: Task<Void, Never>?

    var onHotkeyEvent: ((HotkeyEvent) -> Void)?

    func start() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor in
                self?.handleFlags(event)
            }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor in
                self?.handleFlags(event)
            }
            return event
        }
        // Escape key monitor for toggle mode
        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor in
                if event.keyCode == 53 { // Escape
                    self?.handleEscape()
                }
            }
        }
    }

    func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        pendingFunctionOnlyTask?.cancel()
        globalMonitor = nil
        localMonitor = nil
        keyMonitor = nil
        pendingFunctionOnlyTask = nil
    }

    private func handleFlags(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(Self.relevantModifierMask)

        if flags == [.function] {
            scheduleFunctionOnlyTranscription()
            return
        }

        if let pendingFunctionOnlyTask {
            pendingFunctionOnlyTask.cancel()
            self.pendingFunctionOnlyTask = nil

            if flags.isEmpty {
                activeCombo = .transcription
                onHotkeyEvent?(.down(.transcription))
                activeCombo = nil
                onHotkeyEvent?(.up(.transcription))
                return
            }
        }

        // fn + Shift + Control -> local transcription
        if flags.contains([.function, .shift, .control]) {
            if activeCombo == nil {
                activeCombo = .localTranscription
                onHotkeyEvent?(.down(.localTranscription))
            }
            return
        }

        // fn + Shift -> transcription
        if flags.contains([.function, .shift]) {
            if activeCombo == nil {
                activeCombo = .transcription
                onHotkeyEvent?(.down(.transcription))
            }
            return
        }

        // fn + Control -> Textverbesserer
        if flags.contains([.function, .control]) {
            if activeCombo == nil {
                activeCombo = .textImprover
                onHotkeyEvent?(.down(.textImprover))
            }
            return
        }

        // fn + Option -> Rage Mode
        if flags.contains([.function, .option]) {
            if activeCombo == nil {
                activeCombo = .dampfAblassen
                onHotkeyEvent?(.down(.dampfAblassen))
            }
            return
        }

        // fn + Command -> Emoji Mode
        if flags.contains([.function, .command]) {
            if activeCombo == nil {
                activeCombo = .emojiText
                onHotkeyEvent?(.down(.emojiText))
            }
            return
        }

        // Keys released -- fire up event
        if let combo = activeCombo {
            activeCombo = nil
            onHotkeyEvent?(.up(combo))
        }
    }

    private func scheduleFunctionOnlyTranscription() {
        guard activeCombo == nil, pendingFunctionOnlyTask == nil else { return }

        pendingFunctionOnlyTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.functionOnlyDelayNanoseconds)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard let self, self.activeCombo == nil else { return }
                self.pendingFunctionOnlyTask = nil
                self.activeCombo = .transcription
                self.onHotkeyEvent?(.down(.transcription))
            }
        }
    }

    private func handleEscape() {
        pendingFunctionOnlyTask?.cancel()
        pendingFunctionOnlyTask = nil
        activeCombo = nil
        onHotkeyEvent?(.cancel)
    }
}
