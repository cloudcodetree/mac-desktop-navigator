import Foundation

/// Manages the macOS Mission Control "Switch to Desktop N" symbolic hotkeys.
///
/// macOS does not auto-bind these shortcuts when the user creates a new desktop;
/// without an explicit entry in `com.apple.symbolichotkeys`, the corresponding
/// `Ctrl+N` keystroke does nothing. We check on every launch and silently bind
/// any shortcuts that are missing for desktops the user actually has.
enum HotkeySetup {
    private static let bundleID = "com.apple.symbolichotkeys" as CFString
    private static let key = "AppleSymbolicHotKeys" as CFString

    /// US-layout virtual key codes for digits 1..9 (must match SpaceSwitcher).
    private static let keyCodes = [18, 19, 20, 21, 23, 22, 26, 28, 25]
    private static let controlFlag = 0x40000

    /// Hotkey IDs 118..126 are "Switch to Desktop 1..9". Returns the IDs of
    /// shortcuts that are currently NOT enabled in the user's prefs.
    static func missingShortcuts(forSpaceCount count: Int) -> [Int] {
        let dict = (CFPreferencesCopyAppValue(key, bundleID) as? [String: Any]) ?? [:]
        return (0..<min(count, 9)).compactMap { i in
            let id = String(118 + i)
            let entry = dict[id] as? [String: Any]
            return (entry?["enabled"] as? Bool == true) ? nil : (118 + i)
        }
    }

    /// Adds enabled Ctrl+N entries for any of Desktops 1..N that are missing.
    /// Existing entries are left alone. Returns true if the prefs were written
    /// (i.e. something was missing), so the caller can trigger a system reload.
    @discardableResult
    static func ensureEnabled(forSpaceCount count: Int) -> Bool {
        let missing = missingShortcuts(forSpaceCount: count)
        guard !missing.isEmpty else { return false }

        var dict = (CFPreferencesCopyAppValue(key, bundleID) as? [String: Any]) ?? [:]
        for id in missing {
            let i = id - 118
            let ascii = 49 + i  // '1' = 49
            dict[String(id)] = [
                "enabled": true,
                "value": [
                    "parameters": [ascii, keyCodes[i], controlFlag],
                    "type": "standard",
                ],
            ]
        }
        CFPreferencesSetAppValue(key, dict as CFTypeRef, bundleID)
        CFPreferencesAppSynchronize(bundleID)
        reloadSystemShortcuts()
        return true
    }

    /// Tells SystemUIServer to re-read keyboard shortcut bindings without a logout.
    private static func reloadSystemShortcuts() {
        let activate = "/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings"
        guard FileManager.default.isExecutableFile(atPath: activate) else { return }
        let task = Process()
        task.launchPath = activate
        task.arguments = ["-u"]
        try? task.run()
        task.waitUntilExit()
    }
}
