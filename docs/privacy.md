# Privacy Notes

This fork does not include a hosted backend.

When you use the online workflows, your Mac sends data directly to OpenAI:

- audio recordings for transcription
- transcribed or typed text for rewriting
- custom terms and prompt context if you configured them

When **Sicherer Lokaler Modus** is enabled and a WhisperKit/CoreML model is installed, transcription runs on your Mac and does not send audio to OpenAI. Rewriting workflows still require OpenAI and are paused while secure local mode is active.

There is currently no automatic fallback from failed OpenAI transcription to a local model. Local transcription is used only when secure local mode is enabled or the local transcription shortcut/workflow is selected.

You are responsible for your OpenAI account, API usage, costs, and data handling.

## Local Data

The app stores:

- your OpenAI API key in the user's macOS Keychain
- workflow settings in local app support storage
- the selected microphone device identifier in local app settings
- optional WhisperKit/CoreML model folders in local app support storage
- temporary audio files while a transcription is being processed; the app attempts to delete each recording when the workflow ends or is cancelled

Workflow output may also be placed on your clipboard so it can be pasted into another app. Auto-paste marks the clipboard entry as concealed for compatible clipboard managers, but the generated text intentionally remains on the clipboard as a fallback if automatic paste is blocked. Clipboard managers, macOS, or other apps may still observe clipboard contents while they are present.

If you start dictation while the Desktop or another non-text target is active, the app still writes the result to the clipboard. The simulated paste may do nothing, but the text remains available for manual paste until the clipboard is replaced.

The app uses the system TLS trust store for OpenAI and Hugging Face requests. It does not currently pin certificates. A user-installed or managed root certificate can therefore affect HTTPS trust decisions on that Mac.

Settings such as custom prompts, custom terms, and context are stored in local app support storage as plain JSON. Do not put secrets into those fields.

## Offline Scope

Only transcription can run locally. Any workflow that rewrites, improves, or transforms text still uses OpenAI.

## Sensitive Content

Do not use this preview with confidential, regulated, or highly sensitive content unless you have reviewed the code, your OpenAI settings, and your legal/privacy requirements.
