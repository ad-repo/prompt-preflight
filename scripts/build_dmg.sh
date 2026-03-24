#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# SwiftData macros require the full Xcode toolchain (not just Command Line Tools).
XCODE_PATH="$(xcode-select -p 2>/dev/null || true)"
if [[ "$XCODE_PATH" != *"Xcode.app"* ]]; then
  echo "Error: Xcode is required to build this project (SwiftData macros are not included in Command Line Tools)." >&2
  echo "Install Xcode and run: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer" >&2
  exit 1
fi

APP_NAME="Prompt-Preflight"
EXECUTABLE_NAME="PromptPreflight"
APP_INFO_PLIST="$ROOT_DIR/Info.plist"
BUILD_DIR="$ROOT_DIR/.build/dmg"
APP_BUNDLE="$BUILD_DIR/${APP_NAME}.app"
STAGE_DIR="$BUILD_DIR/stage"
DMG_PATH="$BUILD_DIR/${APP_NAME}.dmg"

if [[ ! -f "$APP_INFO_PLIST" ]]; then
  echo "Error: Info.plist not found at $APP_INFO_PLIST" >&2
  exit 1
fi

echo "==> Building release binary via xcodebuild"
XCODEBUILD_DIR="$ROOT_DIR/.build/xcodebuild"
mkdir -p "$XCODEBUILD_DIR"
xcodebuild \
  -scheme "$EXECUTABLE_NAME" \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "$XCODEBUILD_DIR" \
  -skipPackagePluginValidation \
  -skipMacroValidation

BIN_PATH="$(find "$XCODEBUILD_DIR/Build/Products/Release" -name "$EXECUTABLE_NAME" -type f -not -path '*.dSYM/*' | head -1)"

if [[ -z "$BIN_PATH" || ! -x "$BIN_PATH" ]]; then
  echo "Error: expected executable not found in $XCODEBUILD_DIR/Build/Products/Release" >&2
  exit 1
fi

echo "==> Preparing app bundle"
rm -rf "$APP_BUNDLE" "$STAGE_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources" "$STAGE_DIR"
cp "$BIN_PATH" "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"
cp "$APP_INFO_PLIST" "$APP_BUNDLE/Contents/Info.plist"

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
