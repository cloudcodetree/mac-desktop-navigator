import AppKit

final class SpacesController {
    private(set) var displays: [DisplayInfo] = []
    private(set) var activeSpaceID: CGSSpaceID = 0
    var onChange: (() -> Void)?

    init() {
        refresh()
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(spaceChanged),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
    }

    @objc private func spaceChanged() { refresh() }

    func refresh() {
        displays = SpacesReader.read()
        activeSpaceID = CGSGetActiveSpace(CGSMainConnectionID())
        onChange?()
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
