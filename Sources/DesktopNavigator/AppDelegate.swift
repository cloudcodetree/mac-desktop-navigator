import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var controller: SpacesController!
    private let menu = NSMenu()
    private var eventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller = SpacesController()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        // Note: deliberately NOT setting button.action. We handle clicks via the
        // NSEvent local monitor below, which bypasses NSButton's tracking state
        // machine. NSButton can otherwise get stuck in "tracking" after NSMenu's
        // modal loop consumes a click on the same button, causing the next click
        // to look like a drag continuation and silently no-op.

        buildMenu()

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self,
                  let button = self.statusItem.button,
                  event.window === button.window else { return event }
            self.handleClick(event, on: button)
            return nil
        }

        controller.onChange = { [weak self] in self?.render() }
        render()
    }

    private func render() {
        statusItem.button?.image = DotsRenderer.render(
            displays: controller.displays,
            activeID: controller.activeSpaceID
        )
    }

    private func buildMenu() {
        menu.delegate = self
        let refresh = NSMenuItem(title: "Refresh", action: #selector(refreshAction), keyEquivalent: "r")
        refresh.target = self
        menu.addItem(refresh)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Quit Desktop Navigator",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
    }

    private func handleClick(_ event: NSEvent, on button: NSStatusBarButton) {
        NSLog("DesktopNavigator: MONITOR type=\(event.type.rawValue) flags=0x\(String(event.modifierFlags.rawValue, radix: 16)) loc=\(event.locationInWindow)")
        if event.type == .rightMouseDown {
            showMenu(below: button)
            return
        }
        handleLeftClick(locationInWindow: event.locationInWindow, button: button, source: "monitor")
    }

    private func handleLeftClick(locationInWindow: NSPoint, button: NSStatusBarButton, source: String = "?") {
        let pointInButton = button.convert(locationInWindow, from: nil)
        let imageRect = button.cell?.imageRect(forBounds: button.bounds) ?? button.bounds
        let xInImage = pointInButton.x - imageRect.minX
        let hit = DotsRenderer.hitTest(x: xInImage, in: controller.displays)
        NSLog("DesktopNavigator: HANDLE src=\(source) x=\(xInImage) hit=\(String(describing: hit))")
        switch hit {
        case .dot(let d, let s):
            controller.switchTo(displayIndex: d, spaceIndex: s)
        case .missionControl:
            launchMissionControl()
        case .none:
            break
        }
    }

    private func showMenu(below button: NSStatusBarButton) {
        let location = NSPoint(x: 0, y: button.bounds.height + 4)
        menu.popUp(positioning: nil, at: location, in: button)
    }

    /// Backup path for when NSMenu's tracking consumes the dismiss-click instead
    /// of letting it reach our event monitor.
    func menuDidClose(_ menu: NSMenu) {
        guard let button = statusItem.button, let window = button.window else { return }
        let cursorScreen = NSEvent.mouseLocation
        let buttonRectInWindow = button.convert(button.bounds, to: nil)
        let buttonScreenRect = NSRect(
            x: window.frame.minX + buttonRectInWindow.minX,
            y: window.frame.minY + buttonRectInWindow.minY,
            width: buttonRectInWindow.width,
            height: buttonRectInWindow.height
        )
        guard buttonScreenRect.contains(cursorScreen) else { return }
        let locationInWindow = NSPoint(
            x: cursorScreen.x - window.frame.minX,
            y: cursorScreen.y - window.frame.minY
        )
        DispatchQueue.main.async { [weak self] in
            self?.handleLeftClick(locationInWindow: locationInWindow, button: button, source: "menuDidClose")
        }
    }

    private func launchMissionControl() {
        let url = URL(fileURLWithPath: "/System/Applications/Mission Control.app")
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    @objc private func refreshAction() { controller.refresh() }
}
