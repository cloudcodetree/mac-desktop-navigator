import CoreGraphics

enum SpaceSwitcher {
    /// Virtual key codes for digits 1..9 on the US layout.
    private static let digitKeyCodes: [Int: CGKeyCode] = [
        1: 18, 2: 19, 3: 20, 4: 21, 5: 23,
        6: 22, 7: 26, 8: 28, 9: 25,
    ]
    private static let leftControl: CGKeyCode = 0x3B

    /// Synthesizes a full physical Ctrl+N keystroke (Control down, digit down,
    /// digit up, Control up) to trigger macOS's "Switch to Desktop N" shortcut.
    /// The explicit Control-up at the end is required: without it, observers
    /// like Chrome Remote Desktop can be left thinking Control is still held,
    /// which causes every subsequent click to be treated as a secondary-click.
    @discardableResult
    static func switchTo(_ n: Int) -> Bool {
        guard let keyCode = digitKeyCodes[n],
              let src = CGEventSource(stateID: .combinedSessionState) else { return false }

        let ctrlDown = CGEvent(keyboardEventSource: src, virtualKey: leftControl, keyDown: true)
        let digitDown = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true)
        digitDown?.flags = .maskControl
        let digitUp = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false)
        digitUp?.flags = .maskControl
        let ctrlUp = CGEvent(keyboardEventSource: src, virtualKey: leftControl, keyDown: false)

        ctrlDown?.post(tap: .cghidEventTap)
        digitDown?.post(tap: .cghidEventTap)
        digitUp?.post(tap: .cghidEventTap)
        ctrlUp?.post(tap: .cghidEventTap)
        return true
    }
}
