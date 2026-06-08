#!/usr/bin/env bash
# Uninstall DesktopNavigator: stop the process, remove the LaunchAgent and
# installed bundle. Does NOT delete TCC grants, logs, or system-level
# Switch-to-Desktop shortcuts (those are macOS settings users can manage).

set -euo pipefail

INSTALL_DIR="$HOME/Library/Application Support/DesktopNavigator"
PLIST_PATH="$HOME/Library/LaunchAgents/com.cloudcodetree.DesktopNavigator.plist"

echo "==> Stopping process..."
launchctl bootout "gui/$UID/com.cloudcodetree.DesktopNavigator" 2>/dev/null || true
pkill -x DesktopNavigator 2>/dev/null || true
sleep 1

echo "==> Removing LaunchAgent..."
rm -f "$PLIST_PATH"

echo "==> Removing install directory..."
rm -rf "$INSTALL_DIR"

echo
echo "==> Uninstalled."
echo
echo "Things intentionally NOT removed (manage via System Settings if you want):"
echo "  • Logs at ~/Library/Logs/DesktopNavigator.log"
echo "  • Accessibility & Screen Recording grants in Privacy & Security"
echo "  • 'Switch to Desktop N' shortcuts in Keyboard → Mission Control"
echo "  • DesktopNavigatorSigner certificate in your keychain"
echo
echo "To wipe those too, see the troubleshooting section of the README."
