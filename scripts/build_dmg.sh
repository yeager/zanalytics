#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
APP_PATH="$BUILD_DIR/Release/ZAnalytics.app"
DMG_PATH="$BUILD_DIR/ZAnalytics.dmg"
STAGING_DIR="$BUILD_DIR/dmg-root"

rm -rf "$STAGING_DIR" "$DMG_PATH"
mkdir -p "$BUILD_DIR" "$STAGING_DIR"

xcodebuild \
  -project "$ROOT_DIR/ZAnalytics.xcodeproj" \
  -scheme ZAnalytics \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "$BUILD_DIR/DerivedData" \
  SYMROOT="$BUILD_DIR" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGN_STYLE=Manual \
  build

if [[ ! -d "$APP_PATH" ]]; then
  echo "Expected app not found at $APP_PATH" >&2
  exit 1
fi

cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
  -volname "ZAnalytics" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "Created $DMG_PATH"
