import Foundation

enum HotkeySetup {
    private static let bundleID = "com.apple.symbolichotkeys" as CFString
    private static let key = "AppleSymbolicHotKeys" as CFString

    /// Virtual key codes for digits 1..9 on the US layout (same as SpaceSwitcher).
    private static let keyCodes = [18, 19, 20, 21, 23, 22, 26, 28, 25]
    private static let controlFlag = 0x40000

    /// macOS hotkey IDs 118..126 are "Switch to Desktop 1..9".
    static func areEnabled(count: Int) -> Bool {
        guard let dict = CFPreferencesCopyAppValue(key, bundleID) as? [String: Any] else {
            return false
        }
        for i in 0..<min(count, 9) {
            let entry = dict[String(118 + i)] as? [String: Any]
            if entry?["enabled"] as? Bool != true { return false }
        }
        return true
    }

    /// Writes Ctrl+1..Ctrl+N entries into the symbolichotkeys plist and asks
    /// the system to reload its shortcut bindings.
    @discardableResult
    static func enable(count: Int) -> Bool {
        var dict = (CFPreferencesCopyAppValue(key, bundleID) as? [String: Any]) ?? [:]
        for i in 0..<min(count, 9) {
            let id = String(118 + i)
            let ascii = 49 + i  // '1' = 49
            let entry: [String: Any] = [
                "enabled": true,
                "value": [
                    "parameters": [ascii, keyCodes[i], controlFlag],
                    "type": "standard",
                ],
            ]
            dict[id] = entry
        }
        CFPreferencesSetAppValue(key, dict as CFTypeRef, bundleID)
        let synced = CFPreferencesAppSynchronize(bundleID)
        reloadSystemShortcuts()
        return synced
    }

    /// Triggers SystemUIServer to re-read keyboard shortcut bindings without a logout.
    private static func reloadSystemShortcuts() {
        let activate = "/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings"
        if FileManager.default.isExecutableFile(atPath: activate) {
            let task = Process()
            task.launchPath = activate
            task.arguments = ["-u"]
            try? task.run()
            task.waitUntilExit()
        }
    }
}
