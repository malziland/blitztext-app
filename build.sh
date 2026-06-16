#!/bin/bash
set -euo pipefail

# Blitztext macOS App - Build & Run
# Voraussetzungen: Full Xcode with Command Line Tools, xcodegen

RUN_AFTER=false
INSTALL_APP=false
BUILD_CONFIGURATION="Release"
UNIVERSAL_ARCHS="arm64 x86_64"

# Signing / notarization (opt-in via flags; default stays ad-hoc).
# Personal signing values are NOT committed (this is a public repo). Provide them via:
#   1) a gitignored `signing.local.sh` next to this script (see signing.local.sh.example), or
#   2) environment variables (BLITZTEXT_SIGN_IDENTITY, BLITZTEXT_NOTARY_PROFILE, ...).
SIGN_MODE="adhoc"            # adhoc | developer-id
NOTARIZE=false
SIGN_IDENTITY=""
NOTARY_PROFILE=""
NOTARY_APPLE_ID=""
NOTARY_TEAM_ID=""

for arg in "$@"; do
    case "$arg" in
        --debug)
            BUILD_CONFIGURATION="Debug"
            ;;
        --run)
            RUN_AFTER=true
            ;;
        --install)
            INSTALL_APP=true
            ;;
        --release)
            BUILD_CONFIGURATION="Release"
            ;;
        --developer-id)
            SIGN_MODE="developer-id"
            ;;
        --notarize)
            SIGN_MODE="developer-id"
            NOTARIZE=true
            ;;
        *)
            echo "Unbekannte Option: $arg"
            echo "Verwendung: ./build.sh [--install] [--run] [--release] [--debug] [--developer-id] [--notarize]"
            exit 1
            ;;
    esac
done

verify_universal_app() {
    local app_path="$1"
    local app_name
    local binary_path
    local archs

    app_name="$(basename "$app_path" .app)"
    binary_path="$app_path/Contents/MacOS/$app_name"

    if [ ! -f "$binary_path" ]; then
        echo "❌ Konnte App-Binary nicht finden: $binary_path"
        exit 1
    fi

    archs="$(lipo -archs "$binary_path" 2>/dev/null || true)"

    if [[ -z "$archs" ]]; then
        echo "❌ Konnte Architekturen nicht lesen: $binary_path"
        file "$binary_path" 2>/dev/null || true
        exit 1
    fi

    if [[ " $archs " != *" arm64 "* || " $archs " != *" x86_64 "* ]]; then
        echo "❌ Build ist nicht universal. Erwartet: arm64 + x86_64"
        echo "   Gefunden: $archs"
        file "$binary_path" 2>/dev/null || true
        exit 1
    fi

    echo "✅ Universal Binary verifiziert: $archs"
}

ensure_xcodebuild_available() {
    if xcodebuild -version >/dev/null 2>&1; then
        return
    fi

    local default_xcode="/Applications/Xcode.app/Contents/Developer"
    if [ -d "$default_xcode" ]; then
        export DEVELOPER_DIR="$default_xcode"
        if xcodebuild -version >/dev/null 2>&1; then
            echo "⚠️  Aktiver Developer-Pfad nutzt kein vollständiges Xcode. Verwende: $DEVELOPER_DIR"
            return
        fi
    fi

    echo "❌ xcodebuild ist nicht verfügbar."
    echo "   Installiere Xcode und wähle es mit:"
    echo "   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
    exit 1
}

clean_code_signing_attributes() {
    local target_path="$1"

    if [ ! -e "$target_path" ]; then
        return
    fi

    # macOS file-provider/provenance metadata can break ad-hoc signing with:
    # "resource fork, Finder information, or similar detritus not allowed".
    xattr -cr "$target_path" 2>/dev/null || true
    find "$target_path" -exec xattr -d com.apple.FinderInfo {} + 2>/dev/null || true
    find "$target_path" -exec xattr -d com.apple.ResourceFork {} + 2>/dev/null || true
    find "$target_path" -exec xattr -d "com.apple.fileprovider.fpfs#P" {} + 2>/dev/null || true
}

sign_local_app() {
    local app_path="$1"

    clean_code_signing_attributes "$app_path"
    codesign \
        --force \
        --sign - \
        --options runtime \
        --entitlements "$PROJECT_DIR/Resources/BlitztextMac.entitlements" \
        "$app_path" 2>&1
}

ensure_signing_identity() {
    if [ "$SIGN_MODE" != "developer-id" ]; then
        return
    fi

    if [ -z "$SIGN_IDENTITY" ]; then
        echo "❌ Keine Signing-Identität konfiguriert."
        echo "   Lege 'signing.local.sh' an (Vorlage: signing.local.sh.example)"
        echo "   oder exportiere BLITZTEXT_SIGN_IDENTITY=\"Developer ID Application: ... (TEAMID)\"."
        exit 1
    fi

    # Fail fast (before the long build) if the Developer ID cert is missing.
    if ! security find-identity -v -p codesigning | grep -qF "$SIGN_IDENTITY"; then
        echo "❌ Signing-Identität nicht im Keychain gefunden:"
        echo "   $SIGN_IDENTITY"
        echo "   Verfügbare Code-Signing-Identitäten:"
        security find-identity -v -p codesigning || true
        exit 1
    fi

    echo "🔑 Signiere mit stabiler Identität: $SIGN_IDENTITY"
    if [ "$NOTARIZE" = true ]; then
        echo "   Notarisierung aktiv (Profil: $NOTARY_PROFILE)."
    fi
}

sign_developer_id() {
    local app_path="$1"

    clean_code_signing_attributes "$app_path"

    # Inside-out: sign nested frameworks/dylibs first (deepest first), WITHOUT
    # the app entitlements. The current build links WhisperKit statically and has
    # no Contents/Frameworks, but this stays correct if a dynamic framework is
    # ever embedded. (Apple advises against `codesign --deep` for distribution.)
    if [ -d "$app_path/Contents/Frameworks" ]; then
        find "$app_path/Contents/Frameworks" -depth \
            \( -name "*.framework" -o -name "*.dylib" \) -print0 \
        | while IFS= read -r -d '' nested; do
            codesign --force --options runtime --timestamp \
                --sign "$SIGN_IDENTITY" "$nested"
        done
    fi

    codesign \
        --force \
        --options runtime \
        --timestamp \
        --entitlements "$PROJECT_DIR/Resources/BlitztextMac.entitlements" \
        --sign "$SIGN_IDENTITY" \
        "$app_path" 2>&1
}

sign_app() {
    local app_path="$1"

    if [ "$SIGN_MODE" = "developer-id" ]; then
        echo "🔏 Signiere mit Developer ID (stabile Identität – macOS-Berechtigungen bleiben über Rebuilds erhalten)."
        sign_developer_id "$app_path"
    else
        echo "🔏 Signiere ad-hoc (lokal, nicht notarisiert)."
        echo "   Hinweis: Ad-hoc-Signaturen ändern sich bei jedem Build → macOS setzt Mikrofon-/Bedienungshilfen-Rechte zurück."
        echo "   Für stabile Berechtigungen mit --developer-id (oder --notarize) bauen."
        sign_local_app "$app_path"
    fi
}

quit_running_app() {
    if pgrep -x "Blitztext" >/dev/null 2>&1; then
        echo "🛑 Beende laufende Blitztext-Instanz vor dem Ersetzen ..."
        osascript -e 'quit app "Blitztext"' >/dev/null 2>&1 || true
        sleep 1
        pkill -x "Blitztext" >/dev/null 2>&1 || true
    fi
}

notarize_and_staple() {
    local app_path="$1"
    local zip_path="$SCRIPT_DIR/Blitztext-notarization.zip"

    if [ -z "$NOTARY_PROFILE" ]; then
        echo "❌ Kein Notar-Profil konfiguriert."
        echo "   In 'signing.local.sh' NOTARY_PROFILE setzen oder BLITZTEXT_NOTARY_PROFILE exportieren."
        exit 1
    fi

    echo "📦 Packe App für die Notarisierung ..."
    rm -f "$zip_path"
    ditto --norsrc --noextattr --noqtn --noacl -c -k --keepParent "$app_path" "$zip_path"

    echo "☁️  Sende an den Apple Notary Service (wartet auf das Ergebnis) ..."
    if ! xcrun notarytool submit "$zip_path" \
        --keychain-profile "$NOTARY_PROFILE" \
        --wait; then
        echo "❌ Notarisierung fehlgeschlagen."
        echo "   Falls das Profil '$NOTARY_PROFILE' fehlt, einmalig interaktiv anlegen"
        echo "   (fragt ein App-spezifisches Passwort ab, NICHT das normale Apple-ID-Passwort):"
        echo "   xcrun notarytool store-credentials \"$NOTARY_PROFILE\" \\"
        echo "     --apple-id \"$NOTARY_APPLE_ID\" --team-id \"$NOTARY_TEAM_ID\""
        rm -f "$zip_path"
        exit 1
    fi

    echo "📌 Hefte das Notarisierungs-Ticket an die App (staple) ..."
    xcrun stapler staple "$app_path"
    xcrun stapler validate "$app_path"
    rm -f "$zip_path"
    echo "✅ Notarisierung + Stapling erfolgreich."
}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/BlitztextMac"
PROJECT_FILE="$PROJECT_DIR/BlitztextMac.xcodeproj"
DERIVED_DATA_PATH="$SCRIPT_DIR/.derivedData-blitztextmac-build"

# Load gitignored local signing config (personal values stay off the public repo),
# then let environment variables take precedence over it.
if [ -f "$SCRIPT_DIR/signing.local.sh" ]; then
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/signing.local.sh"
fi
SIGN_IDENTITY="${BLITZTEXT_SIGN_IDENTITY:-$SIGN_IDENTITY}"
NOTARY_PROFILE="${BLITZTEXT_NOTARY_PROFILE:-$NOTARY_PROFILE}"
NOTARY_APPLE_ID="${BLITZTEXT_NOTARY_APPLE_ID:-$NOTARY_APPLE_ID}"
NOTARY_TEAM_ID="${BLITZTEXT_NOTARY_TEAM_ID:-$NOTARY_TEAM_ID}"

cd "$PROJECT_DIR"

ensure_xcodebuild_available
ensure_signing_identity

if command -v xcodegen &> /dev/null; then
    echo "⚙️  Generiere Xcode-Projekt ..."
    xcodegen generate 2>&1
elif [ -d "$PROJECT_FILE" ]; then
    echo "⚠️  xcodegen nicht gefunden – nutze vorhandenes Xcode-Projekt."
else
    echo "❌ xcodegen fehlt."
    echo "   Installiere xcodegen explizit mit:"
    echo "   brew install xcodegen"
    echo "   Oder stelle sicher, dass $PROJECT_FILE vorhanden ist."
    exit 1
fi

# Bauen
echo "🔨 Baue Blitztext ..."
xcodebuild \
    -project BlitztextMac.xcodeproj \
    -scheme BlitztextMac \
    -destination 'platform=macOS' \
    -configuration "$BUILD_CONFIGURATION" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    ONLY_ACTIVE_ARCH=NO \
    ARCHS="$UNIVERSAL_ARCHS" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    clean build

# App finden
APP_PATH="$DERIVED_DATA_PATH/Build/Products/$BUILD_CONFIGURATION/Blitztext.app"

if [ ! -d "$APP_PATH" ]; then
    echo "❌ Build fehlgeschlagen – keine App gefunden."
    exit 1
fi

verify_universal_app "$APP_PATH"

# Resources manuell ins Bundle kopieren (xcodegen kopiert sie nicht automatisch)
echo "📋 Kopiere Resources ..."
RESOURCES_DIR="$APP_PATH/Contents/Resources"
mkdir -p "$RESOURCES_DIR"
cp -f "$PROJECT_DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/" 2>/dev/null || true
cp -f "$PROJECT_DIR/Resources/menubar_icon.png" "$RESOURCES_DIR/" 2>/dev/null || true
cp -f "$PROJECT_DIR/Resources/menubar_icon@2x.png" "$RESOURCES_DIR/" 2>/dev/null || true
clean_code_signing_attributes "$APP_PATH"

# In Projektordner kopieren
DEST="$SCRIPT_DIR/Blitztext.app"
rm -rf "$DEST"
cp -R "$APP_PATH" "$DEST"

# Signieren (ad-hoc oder Developer ID, je nach Flag)
sign_app "$DEST"
verify_universal_app "$DEST"

# Optional notarisieren – das Ticket wird direkt ins Bundle geheftet
if [ "$NOTARIZE" = true ]; then
    notarize_and_staple "$DEST"
fi

RUN_TARGET="$DEST"

if [ "$INSTALL_APP" = true ]; then
    APPS_DIR="/Applications"
    INSTALL_DEST="$APPS_DIR/Blitztext.app"
    if [ ! -w "$APPS_DIR" ]; then
        echo "❌ /Applications ist nicht beschreibbar."
        echo "   Fuehre den Befehl mit passenden Rechten erneut aus oder ziehe die App manuell nach /Applications."
        exit 1
    fi
    # Laufende Instanz beenden, damit Replace + Berechtigungen sauber bleiben
    quit_running_app
    rm -rf "$INSTALL_DEST"
    # Die Kopie übernimmt Signatur (und ggf. das Notar-Ticket) 1:1 – kein erneutes Signieren nötig
    cp -R "$DEST" "$INSTALL_DEST"
    verify_universal_app "$INSTALL_DEST"
    RUN_TARGET="$INSTALL_DEST"
fi

echo ""
echo "✅ Fertig! App liegt unter:"
echo "   $DEST"
if [ "$INSTALL_APP" = true ]; then
    echo "   $RUN_TARGET"
fi
echo ""
SIGN_LABEL="ad-hoc (lokal)"
if [ "$SIGN_MODE" = "developer-id" ]; then
    SIGN_LABEL="Developer ID"
    if [ "$NOTARIZE" = true ]; then
        SIGN_LABEL="Developer ID + notarisiert"
    fi
fi

echo "Build-Typ: $BUILD_CONFIGURATION"
echo "Architekturen: $UNIVERSAL_ARCHS"
echo "Signatur: $SIGN_LABEL"
echo "Kompatibel: Apple Silicon + Intel (macOS 14+)"
echo ""
echo "Naechste Schritte:"
echo "1. App starten"
echo "2. Mikrofon erlauben"
echo "3. Fuer direktes Einfuegen zusaetzlich Bedienungshilfen erlauben"
echo "4. In Blitztext deinen eigenen OpenAI API Key eintragen"
echo "5. Loslegen und bei Bedarf im Code weiterbauen"
if [ "$SIGN_MODE" = "developer-id" ]; then
    echo ""
    echo "ℹ️  Developer-ID-Signatur ist stabil: einmal erteilte Mikrofon-/Bedienungshilfen-Rechte"
    echo "   bleiben ueber kuenftige Builds erhalten. Beim ERSTEN Umstieg von ad-hoc ggf. einmalig:"
    echo "   tccutil reset Accessibility app.blitztext.mac && tccutil reset Microphone app.blitztext.mac"
    echo "   und alte doppelte Blitztext-Eintraege in den Systemeinstellungen entfernen."
fi
echo ""

# Optional: direkt starten
if [ "$RUN_AFTER" = true ]; then
    echo "🚀 Starte Blitztext ..."
    open "$RUN_TARGET"
fi
