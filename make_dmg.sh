#!/bin/bash
# Packages MapToPoster.app into a distributable DMG with an /Applications shortcut.
set -e
cd "$(dirname "$0")"

APP_NAME="MapToPoster"
APP_DIR="$APP_NAME.app"
DMG_NAME="$APP_NAME.dmg"
VERSION=${1:-1.0}

[ -d "$APP_DIR" ] || { echo "Build the app first: ./build_app.sh"; exit 1; }

# Ad-hoc codesign so the app opens without "damaged" warnings on the build machine.
codesign --force --deep --sign - "$APP_DIR" 2>/dev/null || true

STAGE="$(mktemp -d)"
cp -R "$APP_DIR" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

rm -f "$DMG_NAME"
hdiutil create -volname "$APP_NAME $VERSION" \
    -srcfolder "$STAGE" \
    -ov -format UDZO \
    "$DMG_NAME" >/dev/null

rm -rf "$STAGE"
echo "✓ Built $DMG_NAME"
ls -lh "$DMG_NAME"
