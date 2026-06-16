# Architecture

Blitztext is split into a platform-agnostic core and a thin macOS app layer.

```
BlitztextCore  (Swift package, macOS + iOS, no AppKit/AVFoundation)
   ▲
   │  depends on  (the app depends on the core, never the other way around)
   │
BlitztextMac   (the macOS application: platform implementations + SwiftUI UI)
```

## BlitztextCore — the testable core

Everything here is platform-agnostic and unit-tested without launching the app
(`swift test`, runs in well under a second). A future iOS app can reuse it as-is.

- **Domain model:** `WorkflowType`, `WorkflowPhase`, `WorkflowLaunchSource`,
  `HotkeyMode`, `TranscriptionBackend`, the per-workflow `Settings` structs,
  `AppSettings`, `SettingsContainer`, `BlitztextDefaults`.
- **Services (logic + thin I/O):** `LLMService`, `TranscriptionService`,
  `KeychainService` — request building and response parsing are pure functions;
  the network transport is injectable so the full flow is testable without a
  real network.
- **Pure logic:** `TranscriptionQualityService`, `WorkflowLogic`, `HotkeyCombo`,
  `WhisperModelCatalog`, `AudioMetering`, `KeyMasking`, `WorkflowAvailability`,
  `PasteRetry`.
- **Boundaries:** `AudioRecording` protocol (the recording interface the
  workflows depend on).

## BlitztextMac — the macOS app

- **Platform implementations:** `AudioRecorder` (AVFoundation, conforms to
  `AudioRecording`), `HotkeyService` (NSEvent), `LocalTranscriptionService`
  (WhisperKit), `AudioInputDeviceService` (Core Audio),
  `AccessibilityPermissionService`, `LaunchAtLoginService`, etc.
- **Coordinator:** `AppState` wires settings, workflows, the menu-bar status and
  auto-paste together. Its pure rules live in the core; what remains is AppKit
  orchestration.
- **Workflows:** orchestrate recording → transcription → (rewrite) → output.
  Each takes an injectable recorder and injectable transcribe/rewrite closures
  (defaults wire the real services), so the flow is unit-tested with a fake
  recorder.
- **UI:** SwiftUI menu-bar views.

## Testing strategy

- **Core logic** → fast, host-free package tests (the bulk of the coverage).
- **Workflow orchestration** → app-hosted tests driving the workflows with a
  `FakeRecorder` and mock transcribe/rewrite closures.
- **UI and platform glue** (microphone, global hotkey, WhisperKit, the on-screen
  window) → verified by running the app, not by unit tests, as is standard for
  this kind of code.

CI runs both test suites with coverage on every change.
