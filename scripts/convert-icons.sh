#!/bin/bash
# convert-icons.sh <project-root>
# Renders SVG icons to PNG using qlmanage (handles gradients/masks correctly)
# then resizes with sips.
set -euo pipefail

PROJECT_ROOT="${1:?Usage: convert-icons.sh <project-root>}"
SVG_DIR="$PROJECT_ROOT/Courier/Resources/IncomingIcons"
APP_ICON_DIR="$PROJECT_ROOT/Courier/Resources/Assets.xcassets/AppIcon.appiconset"
MENU_BAR_DIR="$PROJECT_ROOT/Courier/Resources/Assets.xcassets/MenuBarIcon.imageset"

TMPDIR_RENDER="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_RENDER"' EXIT

render_svg() {
    local SVG="$1" SIZE="$2" OUT="$3"
    local BASENAME
    BASENAME="$(basename "$SVG")"
    qlmanage -t -s "$SIZE" -o "$TMPDIR_RENDER" "$SVG" 2>/dev/null
    cp "$TMPDIR_RENDER/${BASENAME}.png" "$OUT"
}

resize_png() {
    local SRC="$1" PX="$2" DEST="$3"
    cp "$SRC" "$DEST"
    sips -z "$PX" "$PX" "$DEST" --out "$DEST" > /dev/null
    echo "Wrote $(basename "$DEST") (${PX}x${PX})"
}

# --- App icon ---
APP_ICON_SVG="$SVG_DIR/courier-app-icon-new.svg"
render_svg "$APP_ICON_SVG" 1024 "$TMPDIR_RENDER/appicon_source.png"
SOURCE="$TMPDIR_RENDER/appicon_source.png"

resize_png "$SOURCE" 16   "$APP_ICON_DIR/icon_16x16.png"
resize_png "$SOURCE" 32   "$APP_ICON_DIR/icon_16x16@2x.png"
resize_png "$SOURCE" 32   "$APP_ICON_DIR/icon_32x32.png"
resize_png "$SOURCE" 64   "$APP_ICON_DIR/icon_32x32@2x.png"
resize_png "$SOURCE" 128  "$APP_ICON_DIR/icon_128x128.png"
resize_png "$SOURCE" 256  "$APP_ICON_DIR/icon_128x128@2x.png"
resize_png "$SOURCE" 256  "$APP_ICON_DIR/icon_256x256.png"
resize_png "$SOURCE" 512  "$APP_ICON_DIR/icon_256x256@2x.png"
resize_png "$SOURCE" 512  "$APP_ICON_DIR/icon_512x512.png"
resize_png "$SOURCE" 1024 "$APP_ICON_DIR/icon_512x512@2x.png"

# --- Menu bar icon ---
MENU_BAR_SVG="$SVG_DIR/courier-toolbar-icon.svg"
render_svg "$MENU_BAR_SVG" 36 "$TMPDIR_RENDER/menubar_source.png"
MENU_SOURCE="$TMPDIR_RENDER/menubar_source.png"

resize_png "$MENU_SOURCE" 18 "$MENU_BAR_DIR/menubar-icon.png"
resize_png "$MENU_SOURCE" 36 "$MENU_BAR_DIR/menubar-icon@2x.png"

echo "Done."
