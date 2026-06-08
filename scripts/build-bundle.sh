#!/usr/bin/env bash
# Build DesktopNavigator and assemble it as a .app bundle.
# The bundle ends up at build/DesktopNavigator.app, signed with whatever
# SIGN_IDENTITY is configured (default: DesktopNavigatorSigner).

set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=$(cat VERSION | tr -d '[:space:]')
BUILD=$(git rev-list --count HEAD 2>/dev/null || echo "1")
BUNDLE_ID="com.cloudcodetree.DesktopNavigator"
SIGN_IDENTITY="${SIGN_IDENTITY:-DesktopNavigatorSigner}"

BUILD_DIR="build"
APP="$BUILD_DIR/DesktopNavigator.app"

# Pick configuration: release by default, debug if BUILD_CONFIG=debug
BUILD_CONFIG="${BUILD_CONFIG:-release}"

echo "==> Building $BUILD_CONFIG binary..."
swift build -c "$BUILD_CONFIG"

echo "==> Assembling bundle at $APP (v$VERSION build $BUILD)..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

# Copy binary
cp ".build/$BUILD_CONFIG/DesktopNavigator" "$APP/Contents/MacOS/"

# Generate Info.plist from template
sed -e "s/__VERSION__/$VERSION/g" \
    -e "s/__BUILD__/$BUILD/g" \
    App/Info.plist.template > "$APP/Contents/Info.plist"

# Copy privacy manifest
cp App/PrivacyInfo.xcprivacy "$APP/Contents/Resources/"

# Icon is generated rather than committed (it's a build artifact). Regenerate
# it if missing; users can replace App/AppIcon.icns with a hand-designed one.
if [ ! -f App/AppIcon.icns ]; then
    echo "==> Generating placeholder icon (first build only)..."
    ./scripts/generate-icon.sh >/dev/null
fi
cp App/AppIcon.icns "$APP/Contents/Resources/"

echo "==> Signing with: $SIGN_IDENTITY"
codesign --force --sign "$SIGN_IDENTITY" \
    --identifier "$BUNDLE_ID" \
    "$APP"

echo
echo "==> Bundle ready: $APP"
echo "==> Designated requirement:"
codesign -d -r- "$APP" 2>&1 | tail -2
