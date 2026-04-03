#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-1.0.0}"
APP_NAME="MixMate"
BUNDLE_ID="com.mixmate.app"
BUILD_DIR=".build/release"
STAGING_DIR=".build/dmg-staging"
APP_BUNDLE="$STAGING_DIR/$APP_NAME.app"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"

echo "→ Building $APP_NAME $VERSION"
swift build -c release

echo "→ Assembling .app bundle"
rm -rf "$STAGING_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Process Info.plist — substitute $(EXECUTABLE_NAME) with the actual binary name
sed "s/\$(EXECUTABLE_NAME)/$APP_NAME/g" "MixMate/Info.plist" \
  > "$APP_BUNDLE/Contents/Info.plist"

# Update bundle version from argument
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$APP_BUNDLE/Contents/Info.plist"

chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

echo "→ Ad-hoc signing (prevents Gatekeeper 'damaged' error)"
codesign --force --deep --sign - \
  --entitlements "MixMate/MixMate.entitlements" \
  "$APP_BUNDLE"

echo "→ Creating DMG"
rm -f "$DMG_NAME"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov -format UDZO \
  "$DMG_NAME"

echo "✓ Created $DMG_NAME"
