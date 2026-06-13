# Security Policy

This repository is a personal/local fork of experimental software. It is provided as-is, without warranty, support guarantees, or production-readiness claims.

## Supported Versions

Only the current `main` branch of this fork is considered for fork-specific security fixes.

## Reporting A Vulnerability

Please do not open a public issue with sensitive security details.

If GitHub private vulnerability reporting is available for this repository, use it. Otherwise, open a minimal public issue titled `Security contact request` without technical details.

Do not include OpenAI API keys, access tokens, private recordings, or confidential transcripts in a report.

Include:

- what you found
- how to reproduce it
- what data or system access could be affected
- your suggested fix, if you have one
- whether the issue also appears in the upstream project

## Security Notes

- The app sends audio and text directly to OpenAI when you use remote workflows.
- Your OpenAI API key is stored in the user's macOS Keychain.
- Temporary audio files may exist briefly during processing.
- Accessibility permission allows the app to paste text into the current app.
- The app currently runs without the macOS App Sandbox. Hardened Runtime is enabled, and entitlements are limited to microphone input and outbound network access.

Do not use this preview for confidential or regulated data without your own review.
