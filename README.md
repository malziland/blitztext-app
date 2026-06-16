# Blitztext App - Local Fork

This repository is a personal/local fork of [cmagnussen/blitztext-app](https://github.com/cmagnussen/blitztext-app).

It is not the official upstream project, not a hosted service, and not presented as a separate commercial product. The purpose of this fork is to keep a working local macOS build with a small set of usability changes that are useful for personal testing and day-to-day use.

The upstream project remains the baseline. Local changes in this fork are documented in [CHANGELOG.md](CHANGELOG.md).

> Preview status: bring your own OpenAI API key, no hosted backend, no warranty, no support guarantee.

## What It Does

- **Blitztext**: record speech and transcribe it.
- **Blitztext Lokal**: record speech and transcribe it fully on-device via WhisperKit/CoreML — no audio leaves the Mac.
- **Blitztext+**: record speech, transcribe it, then turn the rough draft into cleaner writing.

Recording is started **only by the global keyboard shortcut** (the menu-bar icon shows the live status and the result is pasted into the app you were typing in). Opening the menu-bar icon shows status, the shortcut reference, and settings — it does not start a recording.

## Fork Notes

- This fork keeps the original app concept and MIT license.
- It adds local macOS usability fixes such as microphone selection, Fn-key shortcut support, clearer recording errors, and local build signing adjustments.
- It does not include a hosted backend.
- It does not include API keys, local models, build products, app bundles, or user data.
- It is not a public release channel. Build from source and review the code before use.

See [FORK.md](FORK.md) for more detail about what is retained, changed, and intentionally removed from this fork.

## Important Preview Notes

- macOS only.
- Bring your own OpenAI API key.
- No hosted Blitztext backend is included or provided.
- In online mode, audio and text are sent directly from the app to the OpenAI API.
- Optional local transcription via WhisperKit/CoreML is available if you install a compatible model locally.
- `./build.sh` creates a locally ad-hoc-signed development app. No notarized release binary is provided.
- Not production ready.
- No warranty and no support guarantee.

## Requirements

- macOS 14 or newer
- Xcode 16 or newer, with Command Line Tools installed and selected for `xcodebuild`
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the Xcode project
- For online transcription and rewriting: an OpenAI API key with access to:
  - `whisper-1` for transcription
  - `gpt-4o-mini` for the "Blitztext+" rewriting workflow
- For local-only transcription: a WhisperKit/CoreML model in:
  `~/Library/Application Support/Blitztext/models/whisperkit/`

The build also pulls one Swift Package dependency automatically:

- [`argmax-oss-swift`](https://github.com/argmaxinc/argmax-oss-swift), used for local on-device transcription via WhisperKit.

Install XcodeGen if needed:

```bash
brew install xcodegen
```

## Build And Run

```bash
git clone https://github.com/malziland/blitztext-app.git
cd blitztext-app
./build.sh --run
```

For a local install into `/Applications`:

```bash
./build.sh --install --run
```

By default the generated `.app` is ad-hoc signed for local development only.

The build script also supports stable signing, which is recommended:

```bash
./build.sh --developer-id --install --run   # stable Developer ID signature
./build.sh --notarize --install --run        # Developer ID + Apple notarization
```

Ad-hoc signatures change on every rebuild, which causes macOS to reset Microphone/Accessibility permissions and create duplicate app entries. A stable **Developer ID** signature keeps those grants across rebuilds. Notarization is only needed to hand the `.app` to other Macs. See [docs/signing.md](docs/signing.md) for the signing modes, the permission fix, and the one-time notarization setup.

On first launch, either paste your own OpenAI API key for online workflows or install a WhisperKit/CoreML model for local transcription. Rewriting workflows still require OpenAI.

For fully local transcription, switch on **Sicherer Lokaler Modus** in the menu-bar popover, then choose and install a WhisperKit/CoreML model there.

For a slower walkthrough, see [docs/setup.md](docs/setup.md).

## Permissions

Blitztext asks for:

- **Microphone**: to record your voice.
- **Accessibility**: to paste the result back into the app you were using.

If you do not grant Accessibility permission, you can still copy results manually.

Full Disk Access is not required. If auto-paste does not work even though transcription succeeds, open **System Settings -> Privacy & Security -> Accessibility**, enable Blitztext there, restart Blitztext, and try again with the cursor focused in a text field. If macOS shows multiple Blitztext entries, remove or disable the old ones and grant the permission to the app you just built or installed.

## Data Flow

The fork has no custom backend.

```text
Online transcription: Your Mac -> OpenAI Audio Transcriptions API
Text rewriting:       Your Mac -> OpenAI Chat Completions API
Local transcription:  Your Mac -> WhisperKit/CoreML on device
```

The app stores your OpenAI API key in the user's macOS Keychain.

Read [docs/privacy.md](docs/privacy.md) before using the preview with sensitive content.

## Project Structure

```text
BlitztextCore/   Platform-agnostic core (Swift package, macOS + iOS), unit-tested
  Sources/       Domain model, settings, LLM/transcription/keychain services, pure logic
  Tests/         Host-free unit tests (swift test)
BlitztextMac/    The macOS app (platform implementations + SwiftUI UI)
  App/           App lifecycle, AppState coordinator, paste handling
  Features/      Workflows, menu bar UI, settings
  Services/      AVFoundation recording, hotkeys, WhisperKit, local storage
  Tests/         App-hosted workflow tests
build.sh         Local build / sign / notarize script
docs/            Setup, privacy, signing, architecture, and repository notes
```

The business logic lives in `BlitztextCore` and is tested; the app is a thin
platform + UI layer. See [docs/architecture.md](docs/architecture.md).

## Local Models

Local transcription is available as an experimental WhisperKit/CoreML path. The app does not bundle a model; from the menu-bar popover, switch on **Sicherer Lokaler Modus**, choose a model, and install it.

See [docs/local-models.md](docs/local-models.md).

## Contributing

This fork is not maintained as a broad public project. General improvements should usually be proposed upstream first. Changes in this fork should stay focused on local macOS use, build reliability, privacy clarity, and the documented fork changes.

See [CONTRIBUTING.md](CONTRIBUTING.md).

## Support And Security

There is no formal support channel or support guarantee for this fork. See [SUPPORT.md](SUPPORT.md).

For sensitive security reports, see [SECURITY.md](SECURITY.md).

## License And Attribution

Code is released under the MIT License. See [LICENSE](LICENSE).

The baseline project is [cmagnussen/blitztext-app](https://github.com/cmagnussen/blitztext-app). This fork keeps attribution and documents local changes separately.

Project names, logos, and app icons are not automatically granted as trademarks or brand assets. See [TRADEMARKS.md](TRADEMARKS.md).
