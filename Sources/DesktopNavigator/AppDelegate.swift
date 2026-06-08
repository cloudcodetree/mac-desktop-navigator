import AppKit
import ApplicationServices

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

        controller.onChange = { [weak self] in
            self?.render()
            self?.ensureShortcutsForCurrentSpaces()
        }
        render()
        ensureShortcutsForCurrentSpaces()
        promptForAccessibilityIfNeeded()
    }

    /// Posting Ctrl+N via CGEvent requires Accessibility permission. If we don't
    /// have it, prompt the user once with the system dialog that links straight
    /// to the right settings pane. Already-trusted processes get no prompt.
    private func promptForAccessibilityIfNeeded() {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
    }

    /// Bind any missing "Switch to Desktop N" shortcuts for desktops the user
    /// currently has. Cheap when nothing's missing (one plist read); silently
    /// self-heals when the user adds a new desktop while the app is running.
    private func ensureShortcutsForCurrentSpaces() {
        let count = controller.displays.first?.spaces.count ?? 0
        HotkeySetup.ensureEnabled(forSpaceCount: count)
    }

    private func render() {
        statusItem.button?.image = DotsRenderer.render(
            displays: controller.displays,
            activeID: controller.activeSpaceID
        )
    }

    private func buildMenu() {
        menu.delegate = self

        let about = NSMenuItem(title: "About Desktop Navigator", action: #selector(showAboutPanel), keyEquivalent: "")
        about.target = self
        menu.addItem(about)
        menu.addItem(.separator())

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

    @objc private func showAboutPanel() {
        // We're LSUIElement (no Dock icon) — the standard About panel only
        // pops up if we explicitly activate ourselves first.
        NSApp.activate(ignoringOtherApps: true)
        let credits = NSAttributedString(
            string: "A menu bar app for switching between Mission Control Spaces.\nhttps://github.com/cloudcodetree/mac-desktop-navigator",
            attributes: [.font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)]
        )
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
    }

    private func handleClick(_ event: NSEvent, on button: NSStatusBarButton) {
        // Pull fresh state before processing the click — the polling timer covers
        // most cases, but a refresh here closes any remaining gap between desktop
        // changes and the user's first click.
        controller.refresh()
        if event.type == .rightMouseDown {
            showMenu(below: button)
            return
        }
        handleLeftClick(locationInWindow: event.locationInWindow, button: button)
    }

    private func handleLeftClick(locationInWindow: NSPoint, button: NSStatusBarButton) {
        let pointInButton = button.convert(locationInWindow, from: nil)
        let imageRect = button.cell?.imageRect(forBounds: button.bounds) ?? button.bounds
        let xInImage = pointInButton.x - imageRect.minX
        let hit = DotsRenderer.hitTest(x: xInImage, in: controller.displays)
        switch hit {
        case .dot(let d, let s):
            controller.switchTo(displayIndex: d, spaceIndex: s)
        case .screenshot:
            takeScreenshot()
        case .missionControl:
            launchMissionControl()
        case .none:
            break
        }
    }

    /// Invokes macOS's interactive selection screenshot tool, routing the
    /// captured image to the clipboard. Equivalent to Shift+Ctrl+Cmd+4 but
    /// doesn't depend on that system shortcut being enabled, and never races
    /// with whatever app currently has key focus.
    private func takeScreenshot() {
        let task = Process()
        task.launchPath = "/usr/sbin/screencapture"
        task.arguments = ["-i", "-c"]
        try? task.run()
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
            self?.handleLeftClick(locationInWindow: locationInWindow, button: button)
        }
    }

    private func launchMissionControl() {
        let url = URL(fileURLWithPath: "/System/Applications/Mission Control.app")
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    @objc private func refreshAction() { controller.refresh() }
}
