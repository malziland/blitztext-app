# Signing & Notarization

This fork can build the macOS app in three signing modes. The default is unchanged
(ad-hoc), and the Developer ID / notarization paths are opt-in via build flags.

| Mode | Flag | Use case |
|---|---|---|
| Ad-hoc (default) | _(none)_ | Quick local build. **Resets macOS permissions on every rebuild** (see below). |
| Developer ID | `--developer-id` | Stable identity for your own Mac. Permissions persist across rebuilds. |
| Developer ID + notarized | `--notarize` | For handing the `.app` to other Macs (Gatekeeper accepts it). |

`--notarize` implies `--developer-id`. All modes always sign **with the entitlements
file** `BlitztextMac/Resources/BlitztextMac.entitlements`, so microphone
(`com.apple.security.device.audio-input`) and network (`com.apple.security.network.client`)
are never lost.

## Why permissions kept resetting (and how this fixes it)

macOS ties Accessibility and Microphone grants (TCC) to the app's **code-signature
identity**. An ad-hoc signature (`codesign --sign -`) changes on every build, so macOS
treats each rebuild as a *different* app: a previously granted permission no longer
applies, the app shows "not authorized" even though you granted it, and stale duplicate
entries pile up in System Settings.

Signing with a **Developer ID** certificate produces a stable designated requirement
(anchored on the team identifier), so macOS recognizes every rebuild as the *same* app
and the grants persist — including across certificate renewals.

## Local signing config (not committed)

Personal signing values (your Developer ID identity, notary profile, Apple ID, Team ID)
are **not** stored in this public repo. Provide them in one of two ways:

1. A gitignored `signing.local.sh` next to `build.sh` — copy the template and edit:

   ```bash
   cp signing.local.sh.example signing.local.sh
   # then edit signing.local.sh with your own values
   ```

   `build.sh` sources it automatically when present.

2. Environment variables, which take precedence over the file:

   ```bash
   BLITZTEXT_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
   BLITZTEXT_NOTARY_PROFILE="your-notary-profile" \
     ./build.sh --notarize --install
   ```

Without either, `--developer-id` / `--notarize` stop early with a clear message. The
default ad-hoc build needs no configuration.

## Recommended local build

```bash
./build.sh --developer-id --install --run
```

For a build you want to distribute to another Mac:

```bash
./build.sh --notarize --install --run
```

Pick **one** canonical location to grant permissions (this repo standardizes on
`/Applications`, installed via `--install`). Don't grant permissions to the app in the
project folder one time and `/Applications` another — different paths confuse TCC.

## One-time migration from ad-hoc to Developer ID

The first time you switch an already-installed ad-hoc app to Developer ID, reset the old
grants once and remove stale duplicate entries:

```bash
tccutil reset Accessibility app.blitztext.mac
tccutil reset Microphone    app.blitztext.mac
```

Then build with `--developer-id --install`, grant Microphone + Accessibility once, and
the grants stick from then on.

## One-time notarization setup

Notarization needs an **app-specific password** for the Apple ID (never the normal
password). Create the keychain profile once, interactively, using your own values:

```bash
xcrun notarytool store-credentials "your-notary-profile" \
  --apple-id "you@example.com" \
  --team-id "YOURTEAMID"
```

The password is entered interactively and stored only in the macOS Keychain — never in
this repo, the code, or any log. Put the matching `NOTARY_PROFILE` into your
`signing.local.sh`. `build.sh --notarize` then submits, waits, staples the ticket into
the bundle, and validates it.

## Verifying a build

```bash
# Signature integrity (passes right after Developer ID signing):
codesign --verify --deep --strict --verbose=2 /Applications/Blitztext.app

# Entitlements actually present on the bundle:
codesign -d --entitlements - /Applications/Blitztext.app

# Gatekeeper policy — only passes AFTER notarization + stapling.
# Before notarization this reports "rejected", which is expected, not a build error.
spctl --assess --type execute --verbose /Applications/Blitztext.app
```
