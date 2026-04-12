#!/bin/bash
# build-dmg.sh — Build, notarize, and staple a distributable Courier DMG
#
# Usage:
#   ./scripts/build-dmg.sh --apple-id YOUR_APPLE_ID --password YOUR_APP_SPECIFIC_PASSWORD
#
# Prerequisites:
#   - brew install create-dmg
#   - A notarized, stapled Courier.app in the EXPORT_PATH below
#   - Developer ID Application certificate in your keychain

set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────────────
TEAM_ID="FL2978XX59"
APP_NAME="Courier Launcher"
VERSION="1.0.0"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EXPORT_PATH="$REPO_ROOT/build/export/Courier Launcher.app"
DMG_NAME="Courier-${VERSION}.dmg"
DMG_OUT="$REPO_ROOT/$DMG_NAME"

# ── Parse arguments ───────────────────────────────────────────────────────────
APPLE_ID=""
PASSWORD=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --apple-id) APPLE_ID="$2"; shift 2 ;;
        --password) PASSWORD="$2"; shift 2 ;;
        *) echo "Unknown argument: $1"; exit 1 ;;
    esac
done

if [[ -z "$APPLE_ID" || -z "$PASSWORD" ]]; then
    echo "Usage: $0 --apple-id YOUR_APPLE_ID --password YOUR_APP_SPECIFIC_PASSWORD"
    exit 1
fi

# ── Verify app exists ─────────────────────────────────────────────────────────
if [[ ! -d "$EXPORT_PATH" ]]; then
    echo "Error: App not found at: $EXPORT_PATH"
    echo "Export a notarized build from Xcode first."
    exit 1
fi

# ── Build DMG ─────────────────────────────────────────────────────────────────
echo "→ Building DMG..."
[[ -f "$DMG_OUT" ]] && rm "$DMG_OUT"

# Stage just the app into a temp folder so create-dmg doesn't pick up repo artifacts
STAGING=$(mktemp -d)
cp -R "$EXPORT_PATH" "$STAGING/"
trap "rm -rf '$STAGING'" EXIT

create-dmg \
    --volname "Courier" \
    --window-size 540 380 \
    --icon-size 128 \
    --icon "${APP_NAME}.app" 140 190 \
    --app-drop-link 400 190 \
    --hide-extension "${APP_NAME}.app" \
    "$DMG_OUT" \
    "$STAGING/"

# ── Notarize DMG ─────────────────────────────────────────────────────────────
echo "→ Notarizing DMG (this takes a few minutes)..."
xcrun notarytool submit "$DMG_OUT" \
    --apple-id "$APPLE_ID" \
    --team-id "$TEAM_ID" \
    --password "$PASSWORD" \
    --wait

# ── Staple DMG ───────────────────────────────────────────────────────────────
echo "→ Stapling notarization ticket..."
xcrun stapler staple "$DMG_OUT"

# ── Verify ───────────────────────────────────────────────────────────────────
echo "→ Verifying..."
xcrun stapler validate "$DMG_OUT"

echo ""
echo "✓ Done: $DMG_OUT"
