#!/bin/bash
# Builds WhisperKey.app from the Swift package.
# Run on a Mac with Xcode (or the Command Line Tools + Swift toolchain).
set -euo pipefail
cd "$(dirname "$0")/.."

echo "▸ Building release binary…"
swift build -c release

APP="build/WhisperKey.app"
BIN="$(swift build -c release --show-bin-path)/WhisperKey"

echo "▸ Assembling $APP…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/WhisperKey"
cp Resources/Info.plist "$APP/Contents/Info.plist"

echo "▸ Code signing (ad-hoc)…"
codesign --force --deep --sign - "$APP"

echo
echo "✓ Done: $APP"
echo "  Move it to /Applications and launch it:"
echo "    mv -f $APP /Applications/ && open /Applications/WhisperKey.app"
