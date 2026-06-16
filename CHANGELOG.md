# Changelog

All notable changes to this fork are documented here.

This fork tracks local macOS usability fixes for running Blitztext without a hosted backend. The original upstream project remains the source of the baseline app.

## 2026-06-16 — Architecture refactoring

A behavior-neutral restructuring that separates the business logic from the macOS
platform/UI layer and puts it under test. Verified by the test suite and a hands-on
run-test; a read-only audit of the refactoring found no regressions.

### Added

- New platform-agnostic Swift package `BlitztextCore` (macOS + iOS) holding the domain
  model, settings, `LLMService` / `TranscriptionService` / `KeychainService`, and the
  pure logic (transcription-quality, workflow decisions, hotkey mapping, the Whisper
  model catalog, key masking, workflow availability, paste backoff). It can be reused
  by a future iOS app.
- A test suite from scratch: **88 tests** (82 host-free core tests via `swift test`,
  6 app-hosted workflow tests), ≈86% line coverage of the core logic. Network and
  response-parsing logic was made testable via an injectable HTTP transport and
  extracted pure functions, with no real network calls in tests.
- `docs/architecture.md` documenting the core/app split and the testing strategy.

### Changed

- The four workflows now take an injectable recorder (`AudioRecording` protocol) plus
  injectable transcribe/rewrite closures (defaults wire the real services), so the full
  record → transcribe → (rewrite) → output flow is unit-tested with a fake recorder. The
  live UI/recording path is unchanged.
- CI now runs **both** test suites on every change (`swift test` for the package and
  `xcodebuild test` for the app); previously only the 6 app tests ran in CI.

## 2026-06-16 — Audit remediation

Read-only security/reliability audit of the repository; all eight P3 findings fixed (no higher-severity issues were found).

### Fixed

- Recording stop fallback (`AudioRecorder.scheduleStopFallback`): when the capture delegate does not finalize the file within the timeout, the app now surfaces a "please try again" error and discards the unfinalized file instead of transcribing a possibly partial recording.
- Orphaned temporary recordings: added `AudioRecorder.cleanupOrphanedRecordings()`, called at launch, to sweep `blitztext-*` files left in the temporary directory by a previous run that was hard-killed before its per-workflow cleanup ran (defense in depth for the `defer`-based deletion that already covers normal and error paths).
- README listed `gpt-4o` as "optionally … for rewriting", but the "Blitztext $%&!" workflow always requires it. README now states which model each workflow uses, matching `docs/setup.md`.

### Changed

- CI secret-hygiene scan now also scans the **full Git history** (not just the working tree) and gained a targeted pattern for a hardcoded Apple signing identity with a real Team ID (the `signing.local.sh.example` placeholder does not match). `actions/checkout` is now pinned to a commit SHA (`df4cb1c`, v6.0.3) instead of a mutable tag, with `fetch-depth: 0` for the history scan.
- The `argmax-oss-swift` (WhisperKit) dependency is now pinned to the immutable commit of tag `v0.18.0` (`revision:` in `project.yml`) instead of a movable version tag, so a re-pushed tag cannot silently change what is pulled.
- Scrubbed the personal signing identifiers that an earlier commit had introduced into `build.sh`/`docs/signing.md` from the **entire Git history** (history rewrite + force-push), not just from `HEAD`.

## 2026-06-16

### Added

- Added optional Developer ID signing (`./build.sh --developer-id`) so rebuilds keep a stable code-signature identity. This prevents macOS from resetting Microphone/Accessibility permissions on every build, which previously made grants appear lost and created duplicate Blitztext entries.
- Added optional notarization (`./build.sh --notarize`): zips the app, submits to the Apple Notary Service, staples the ticket into the bundle, and validates it.
- Added a pre-build check that fails fast with a clear message if the configured Developer ID identity is missing from the keychain.
- Added `docs/signing.md` documenting the signing modes, the permission-reset root cause, the one-time TCC migration, and the one-time notarization profile setup.

### Changed

- Kept personal signing values (Developer ID identity, notary profile, Apple ID, Team ID) out of the public repo: `build.sh` now reads them from a gitignored `signing.local.sh` (template: `signing.local.sh.example`) or environment variables, and stops with a clear message if `--developer-id`/`--notarize` is used without them.
- Signing always uses the existing entitlements file, so microphone and network entitlements are never dropped. Dropped `codesign --deep` in favor of an inside-out approach (Apple advises against `--deep` for distribution).
- On `--install`, the running Blitztext instance is now quit before the app in `/Applications` is replaced, and the installed copy reuses the already-signed (and, if notarized, stapled) bundle instead of being re-signed.
- The build summary now reports the signing mode, and ad-hoc builds print a hint to use `--developer-id` for stable permissions.

### Fixed

- Ignored the notarization zip (`Blitztext-notarization.zip`, `*.zip`) so signing artifacts are never committed.

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
