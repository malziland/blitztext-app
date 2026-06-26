# Changelog

All notable changes to this fork are documented here.

This fork tracks local macOS usability fixes for running Blitztext without a hosted backend. The original upstream project remains the source of the baseline app.

## 2026-06-26

### Added

- **Automatic formatting of transcripts** (Groß-/Kleinschreibung, Satzzeichen, Absätze),
  controlled by a new "Automatisch formatieren" toggle in the "Anpassen" settings tab
  (`AppSettings.formatTranscription`, default on). It runs after transcription on the plain
  **Blitztext** and **Blitztext Lokal** workflows; **Blitztext+** is unaffected (it already
  rewrites).
  - **Online** (remote Whisper): a formatting-only pass via `gpt-4o-mini`
    (`LLMService.format`, temperature 0) that fixes capitalization, punctuation and
    paragraph/line breaks **without changing the wording**. It also turns spoken dictation
    marks ("Punkt", "Komma", "neue Zeile", "neuer Absatz", …) into real punctuation/breaks.
  - **Offline** (secure local mode): a deterministic, on-device formatter
    (`TranscriptFormatter` in `BlitztextCore`) — sentence-start capitalization, whitespace
    normalization, and spoken structural commands ("neue Zeile", "neuer Absatz",
    "Fragezeichen", "Ausrufezeichen", "Doppelpunkt"). It never sends anything to OpenAI, so
    the secure-local privacy guarantee is preserved. "Punkt"/"Komma" are intentionally not
    auto-converted offline (too many false positives); they are handled in context by the
    online pass. German noun capitalization is left to the online pass.
  - If the online pass fails, the workflow degrades to the offline formatter so a formatting
    error never loses the dictation.

### Changed

- **Better raw transcription, no extra request:** the Whisper `prompt` field is now always
  seeded with a correctly written German sentence (capitalization + punctuation) when the
  language is German, so the transcript already comes back better formatted. Custom terms are
  appended as before (`TranscriptionService.transcriptionPrompt`).
- **Plausibility guard on the online formatting pass:** if the model returns something that is
  not a reformat (a rewrite, an appended explanation, a refusal, runaway repetition), the
  result is rejected and the offline formatter is used instead
  (`TranscriptFormatter.isPlausibleReformatting`, an alphanumeric-length check).
- **Skip the paid format call for trivial utterances** (≤ 3 words like "ja danke"): they use
  the offline formatter directly, saving a round-trip and cost
  (`TranscriptFormatter.isTrivialForOnlineFormatting`).

## 2026-06-16

A large round of work on this fork: the logic was split into a tested, platform-agnostic
core; two workflows and several UI elements were removed; dictation was reduced to a
keyboard-shortcut-only background flow; and Developer ID signing/notarization plus a
security audit were added. All changes were verified by the test suite and hands-on
run-tests.

### Added

- **`BlitztextCore`** — a platform-agnostic Swift package (macOS + iOS) holding the domain
  model, settings, `LLMService` / `TranscriptionService` / `KeychainService`, and the pure
  logic (transcription quality, workflow decisions, hotkey mapping, the Whisper model
  catalog, key masking, workflow availability, paste backoff). It can be reused by a future
  iOS app.
- A **test suite from scratch** — host-free core tests (`swift test`) plus app-hosted
  workflow tests driven by a `FakeRecorder` and injectable transcribe/rewrite closures, with
  no real network calls (injectable HTTP transport). Currently 80 core + 6 app tests.
- **Developer ID signing** (`./build.sh --developer-id`) and **notarization**
  (`./build.sh --notarize`): a stable code-signature identity so macOS no longer resets
  Microphone/Accessibility permissions on every rebuild; the notary ticket is stapled into
  the bundle. A pre-build check fails fast if the configured identity is missing.
- `docs/architecture.md` (core/app split + testing strategy) and `docs/signing.md` (signing
  modes, the permission-reset root cause, the one-time TCC migration, notary profile setup).

### Changed

- **Dictation is now triggered only by the global keyboard shortcut**, recording in the
  **background**: the menu-bar icon shows the state and the result is pasted into the app
  that was frontmost when recording began. Clicking the menu no longer records. Both hotkey
  modes (hold / toggle) record in the background. The menu-bar popover now shows status, a
  non-interactive shortcut reference, and settings instead of tappable workflow rows.
- The remaining workflows are **Blitztext** (transcription), **Blitztext Lokal** (on-device
  transcription), and **Blitztext+** (transcribe + rewrite). The only rewriting model in use
  is `gpt-4o-mini`.
- The **Sicherer Lokaler Modus** switch now lives only in the menu-bar popover (toggle +
  model selection + download); the duplicate Settings-page section was removed.
- The workflows take an injectable recorder (`AudioRecording` protocol) plus injectable
  transcribe/rewrite closures, so the full record → transcribe → (rewrite) → output flow is
  unit-tested with a fake recorder.
- Signing hygiene: personal signing values stay out of the repo (read from a gitignored
  `signing.local.sh` or environment variables); signing always uses the entitlements file;
  `codesign --deep` was replaced with an inside-out approach; on `--install` the running app
  is quit first and the already-signed/stapled bundle is reused.
- CI now runs **both** test suites on every change (`swift test` + `xcodebuild test`); the
  `actions/checkout` action and the `argmax-oss-swift` (WhisperKit) dependency are pinned to
  immutable commits; the secret-hygiene scan covers the full Git history.

### Removed

- The **Blitztext $%&!** (calmer-message) and **Blitztext :)** (emoji) workflows — deleted
  from the code entirely: enum cases, workflow files, settings types
  (`DampfAblassenSettings`, `EmojiTextSettings`), `LLMService` methods, the fn+option /
  fn+command hotkey mappings, menu-bar badges, settings panels, and active views. Old
  settings files that still contain these keys decode without error (the keys are ignored).
- The "Updates" and "Hinweis" info boxes in Settings and the "macOS Preview" label.
- The click-to-record path and the in-popover recording window (waveform + stop button),
  including the now-dead `WorkflowLaunchSource`, the `.workflow` popover page,
  `TranscriptionActiveView` / `TextImproverActiveView`, and `WaveformView`.
- Dead/orphaned code: the unused `copyToClipboard` and `stopCurrentWorkflow` methods, the
  `installedLocalModels` / `localModelOptions` helpers, the empty `Views/` folder, and stale
  migration comments.
- Personal signing identifiers an earlier commit had introduced into `build.sh` /
  `docs/signing.md` were scrubbed from the **entire Git history** (rewrite + force-push).

### Fixed

- Recording stop fallback (`AudioRecorder.scheduleStopFallback`): if the capture delegate
  does not finalize the file within the timeout, the app surfaces a "please try again" error
  and discards the unfinalized file instead of transcribing a partial recording.
- Orphaned temporary recordings: `AudioRecorder.cleanupOrphanedRecordings()` runs at launch
  to sweep `blitztext-*` temp files left by a previous run that was hard-killed before its
  per-workflow cleanup ran.
- README now states which model each workflow uses (no stale `gpt-4o`), matching
  `docs/setup.md`. The notarization zip (`Blitztext-notarization.zip`, `*.zip`) is gitignored
  so signing artifacts are never committed.

## 2026-06-13

### Added

- Added explicit microphone input selection in settings, including a system default option and persisted device selection.
- Added support for using the Fn key alone for the main Blitztext transcription shortcut.
- Added visible last-error feedback in the menu bar popover so recording and permission errors are easier to diagnose.
- Added recording quality checks for very short recordings, silent input, and known transcription artifacts.

### Changed

- Changed the default main transcription mode to press-to-toggle recording.
- Improved hotkey handling so Fn combinations still work while allowing Fn alone for transcription.
- Reworked audio recording to use a capture session with the selected input device instead of relying only on the system-selected recorder input.
- Improved macOS permission prompting for Accessibility access.
- Updated the local build script to create an ad-hoc-signed app suitable for local installation and testing.

### Fixed

- Fixed cases where macOS hotkeys and auto-paste still appeared blocked after permissions were granted.
- Fixed unreliable microphone selection when an external microphone should be used.
- Reduced false transcriptions such as "Untertitel der Amara-Community" after unusable recordings.
- Ignored locally built `.app` bundles so they are not accidentally committed.

### Documentation

- Clarified that this repository is a personal/local fork of the upstream Blitztext app.
- Added fork notes describing retained files, local changes, intentionally excluded data, and upstream relationship.
- Updated setup, privacy, support, security, contribution, and GitHub hygiene notes for a fork context.
- Documented that there is currently no automatic OpenAI-to-local transcription fallback.
- Documented that generated text remains on the clipboard if auto-paste has no valid text target.

### Removed

- Removed upstream-facing roadmap, launch-page, and public preflight documents that did not describe this fork.
