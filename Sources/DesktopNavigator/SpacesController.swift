import AppKit

final class SpacesController {
    private(set) var displays: [DisplayInfo] = []
    private(set) var activeSpaceID: CGSSpaceID = 0
    var onChange: (() -> Void)?

    private var pollTimer: Timer?

    init() {
        refresh()
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(spaceChanged),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
        // macOS does not notify us when a desktop is added or removed without a
        // switch, so we poll. CGSCopyManagedDisplaySpaces is cheap (~1ms) and we
        // only fire onChange when state actually changed, so the polling overhead
        // is negligible.
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    @objc private func spaceChanged() { refresh() }

    func refresh() {
        let newDisplays = SpacesReader.read()
        let newActive = CGSGetActiveSpace(CGSMainConnectionID())
        let changed = newActive != activeSpaceID || !sameLayout(newDisplays, displays)
        displays = newDisplays
        activeSpaceID = newActive
        if changed { onChange?() }
    }

    /// Compare just the structural shape (display count + per-display space count
    /// + space IDs). That's everything render and hit-test depend on; ignore
    /// fields like uuid or type since they don't affect output.
    private func sameLayout(_ a: [DisplayInfo], _ b: [DisplayInfo]) -> Bool {
        guard a.count == b.count else { return false }
        for (i, d) in a.enumerated() {
            let other = b[i]
            guard d.spaces.count == other.spaces.count else { return false }
            for (j, s) in d.spaces.enumerated() {
                if s.id != other.spaces[j].id { return false }
            }
        }
        return true
    }

    /// Ctrl+N only targets the focused display, so v1 only switches on the primary one.
    @discardableResult
    func switchTo(displayIndex: Int, spaceIndex: Int) -> Bool {
        guard displayIndex == 0,
              displayIndex < displays.count,
              spaceIndex < displays[displayIndex].spaces.count else { return false }
        return SpaceSwitcher.switchTo(spaceIndex + 1)
    }
}
