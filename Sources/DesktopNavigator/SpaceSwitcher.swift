import CoreGraphics

enum SpaceSwitcher {
    /// Virtual key codes for digits 1..9 on the US layout.
    private static let digitKeyCodes: [Int: CGKeyCode] = [
        1: 18, 2: 19, 3: 20, 4: 21, 5: 23,
        6: 22, 7: 26, 8: 28, 9: 25,
    ]

    /// Synthesizes Ctrl+N to trigger macOS's "Switch to Desktop N" shortcut.
    /// Requires that the shortcut is enabled in System Settings (see HotkeySetup).
    @discardableResult
    static func switchTo(_ n: Int) -> Bool {
        guard let keyCode = digitKeyCodes[n],
              let src = CGEventSource(stateID: .combinedSessionState) else { return false }

        let down = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true)
        down?.flags = .maskControl
        let up = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false)
        up?.flags = .maskControl

        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
        return true
    }
}
