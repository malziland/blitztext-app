# Changelog

All notable changes to this fork are documented here.

This fork tracks local macOS usability fixes for running Blitztext without a hosted backend. The original upstream project remains the source of the baseline app.

## 2026-06-16

### Added

- Added optional Developer ID signing (`./build.sh --developer-id`) so rebuilds keep a stable code-signature identity. This prevents macOS from resetting Microphone/Accessibility permissions on every build, which previously made grants appear lost and created duplicate Blitztext entries.
- Added optional notarization (`./build.sh --notarize`): zips the app, submits to the Apple Notary Service, staples the ticket into the bundle, and validates it.
- Added a pre-build check that fails fast with a clear message if the configured Developer ID identity is missing from the keychain.
- Added `docs/signing.md` documenting the signing modes, the permission-reset root cause, the one-time TCC migration, and the one-time notarization profile setup.

### Changed

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
