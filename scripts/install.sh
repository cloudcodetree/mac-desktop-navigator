#!/usr/bin/env bash
# Install DesktopNavigator: build the bundle, install it to the right place,
# register a LaunchAgent, and start the process. Idempotent — running it
# multiple times just redeploys the current build.

set -euo pipefail
cd "$(dirname "$0")/.."

INSTALL_DIR="$HOME/Library/Application Support/DesktopNavigator"
APP_NAME="DesktopNavigator.app"
INSTALLED_APP="$INSTALL_DIR/$APP_NAME"
PLIST_PATH="$HOME/Library/LaunchAgents/com.cloudcodetree.DesktopNavigator.plist"
LOG_DIR="$HOME/Library/Logs"
LOG_FILE="$LOG_DIR/DesktopNavigator.log"

# 1. Ensure a signing identity exists
if ! security find-identity -v -p codesigning | grep -q "DesktopNavigatorSigner"; then
    echo "==> No DesktopNavigatorSigner identity found. Creating one..."
    ./scripts/create-signer.sh
fi

# 2. Build the bundle
./scripts/build-bundle.sh

# 3. Stop any running instance — must be done BEFORE replacing the binary
echo "==> Stopping any existing instance..."
launchctl bootout "gui/$UID/com.cloudcodetree.DesktopNavigator" 2>/dev/null || true
sleep 1

# 4. Clear any prior install (bare binary from older versions OR previous bundle)
echo "==> Installing to $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR"
rm -rf "$INSTALL_DIR/DesktopNavigator"   # old bare-binary install path
rm -rf "$INSTALLED_APP"
cp -R "build/$APP_NAME" "$INSTALLED_APP"

# 5. Write the LaunchAgent plist pointing at the bundle's binary
echo "==> Writing LaunchAgent at $PLIST_PATH..."
mkdir -p "$LOG_DIR"
cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.cloudcodetree.DesktopNavigator</string>

    <key>ProgramArguments</key>
    <array>
        <string>$INSTALLED_APP/Contents/MacOS/DesktopNavigator</string>
    </array>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
    </dict>

    <key>ProcessType</key>
    <string>Interactive</string>

    <key>StandardOutPath</key>
    <string>$LOG_FILE</string>

    <key>StandardErrorPath</key>
    <string>$LOG_FILE</string>
</dict>
</plist>
EOF

# 6. Start
echo "==> Starting via launchd..."
launchctl bootstrap "gui/$UID" "$PLIST_PATH"
sleep 2

PID=$(pgrep -x DesktopNavigator || true)
if [ -n "$PID" ]; then
    echo
    echo "==> Installed and running. PID: $PID"
    echo "==> Bundle: $INSTALLED_APP"
    echo
    echo "If this is your first install, macOS will prompt for Accessibility"
    echo "permission when you first click a rectangle. Click 'Open System"
    echo "Settings' on the dialog and toggle DesktopNavigator on."
else
    echo
    echo "==> WARNING: process didn't start. Check $LOG_FILE for details."
    exit 1
fi
