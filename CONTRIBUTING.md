# Contributing

This repository is a personal/local fork, not the official upstream project.

General changes that should benefit all users are usually better proposed to the upstream project first:

https://github.com/cmagnussen/blitztext-app

Changes in this fork should stay focused on:

- local macOS build reliability
- local setup and permission handling
- microphone and hotkey usability
- clear privacy and data-flow documentation
- small fixes needed for this fork's documented behavior

## Before Opening A Pull Request

Please include:

- what changed
- why it changed
- how you tested it
- whether the change is fork-specific or suitable for upstream
- whether you used AI-assisted coding tools

Keep changes small when possible. Avoid unrelated cleanup in the same pull request.

## Local Build

```bash
./build.sh --debug
```

## Security And Privacy

- Never commit API keys, tokens, private audio, or confidential transcripts.
- Do not add telemetry, hosted services, or new external services without a clear reason.
- Call out privacy-impacting changes in the pull request description.
- Keep the preview honest: do not describe remote OpenAI workflows as offline or local.

## Project Boundaries

This fork currently does not provide:

- production support
- hosted infrastructure
- packaged public releases
- bundled local model files
- local text rewriting
- a separate public product roadmap
