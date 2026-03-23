#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Prompt-Preflight"
EXECUTABLE_NAME="PromptPreflight"
BUNDLE_ID="${BUNDLE_ID:-com.promptpreflight.app}"
VERSION="${VERSION:-1.0.0}"
BUILD_DIR="$ROOT_DIR/.build/dmg"
APP_BUNDLE="$BUILD_DIR/${APP_NAME}.app"
STAGE_DIR="$BUILD_DIR/stage"
DMG_PATH="$BUILD_DIR/${APP_NAME}.dmg"

echo "==> Building release binary"
swift build -c release --package-path "$ROOT_DIR" --product "$EXECUTABLE_NAME"
BIN_DIR="$(swift build -c release --package-path "$ROOT_DIR" --show-bin-path)"
BIN_PATH="$BIN_DIR/$EXECUTABLE_NAME"

if [[ ! -x "$BIN_PATH" ]]; then
  echo "Error: expected executable not found at $BIN_PATH" >&2
  exit 1
fi

echo "==> Preparing app bundle"
rm -rf "$APP_BUNDLE" "$STAGE_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources" "$STAGE_DIR"
cp "$BIN_PATH" "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"

cat >"$APP_BUNDLE/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>${EXECUTABLE_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${VERSION}</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
</dict>
</plist>
EOF

if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
  echo "==> Codesigning app bundle"
  codesign --deep --force --options runtime --sign "$CODESIGN_IDENTITY" "$APP_BUNDLE"
fi

echo "==> Staging DMG contents"
cp -R "$APP_BUNDLE" "$STAGE_DIR/"
ln -s /Applications "$STAGE_DIR/Applications"

echo "==> Creating DMG"
rm -f "$DMG_PATH"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGE_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "Done: $DMG_PATH"
