import AppKit

final class SpaceTarget: NSObject {
    let displayIndex: Int
    let spaceIndex: Int
    init(displayIndex: Int, spaceIndex: Int) {
        self.displayIndex = displayIndex
        self.spaceIndex = spaceIndex
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var dotsItem: NSStatusItem!
    private var menuItem: NSStatusItem!
    private var controller: SpacesController!
    private let menu = NSMenu()

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller = SpacesController()

        // Clickable dots — action mode only, no attached menu.
        dotsItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = dotsItem.button {
            button.action = #selector(dotClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseDown])
        }

        // Chevron — menu mode only. AppKit owns the entire interaction,
        // so outside-click dismissal is consumed by NSMenu's tracking loop.
        menuItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        menuItem.button?.image = DotsRenderer.renderChevron()
        menu.delegate = self
        menuItem.menu = menu

        controller.onChange = { [weak self] in self?.renderDots() }
        renderDots()
    }

    private func renderDots() {
        dotsItem.button?.image = DotsRenderer.renderDots(
            displays: controller.displays,
            activeID: controller.activeSpaceID
        )
    }

    @objc private func dotClicked(_ sender: Any?) {
        guard let event = NSApp.currentEvent, let button = dotsItem.button else { return }
        let pointInButton = button.convert(event.locationInWindow, from: nil)
        let imageRect = button.cell?.imageRect(forBounds: button.bounds) ?? button.bounds
        let xInImage = pointInButton.x - imageRect.minX
        guard let hit = DotsRenderer.dotAt(x: xInImage, in: controller.displays) else { return }
        controller.switchTo(displayIndex: hit.display, spaceIndex: hit.space)
    }

    // MARK: - Menu (chevron status item)

    func menuNeedsUpdate(_ menu: NSMenu) {
        controller.refresh()
        menu.removeAllItems()

        let activeID = controller.activeSpaceID
        let multipleDisplays = controller.displays.count > 1

        for (di, display) in controller.displays.enumerated() {
            if multipleDisplays {
                let header = NSMenuItem(
                    title: display.identifier == "Main" ? "Main Display" : "Display \(di + 1)",
                    action: nil,
                    keyEquivalent: ""
                )
                header.isEnabled = false
                menu.addItem(header)
            }
            for (si, space) in display.spaces.enumerated() {
                let title: String = (space.type == 4) ? "Fullscreen \(si + 1)" : "Desktop \(si + 1)"
                let item = NSMenuItem(
                    title: title,
                    action: #selector(menuItemSelected(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = SpaceTarget(displayIndex: di, spaceIndex: si)
                if space.id == activeID { item.state = .on }
                menu.addItem(item)
            }
            if di < controller.displays.count - 1 { menu.addItem(.separator()) }
        }

        menu.addItem(.separator())

        let spaceCount = controller.displays.first?.spaces.count ?? 0
        if !HotkeySetup.areEnabled(count: spaceCount) {
            let warn = NSMenuItem(title: "⚠︎ Switch-to-Desktop shortcuts not enabled", action: nil, keyEquivalent: "")
            warn.isEnabled = false
            menu.addItem(warn)
            let enable = NSMenuItem(title: "Enable Switch-to-Desktop shortcuts", action: #selector(enableShortcutsAction), keyEquivalent: "")
            enable.target = self
            menu.addItem(enable)
            let openPrefs = NSMenuItem(title: "Open System Settings…", action: #selector(openMissionControlPrefs), keyEquivalent: "")
            openPrefs.target = self
            menu.addItem(openPrefs)
            menu.addItem(.separator())
        }

        let refresh = NSMenuItem(title: "Refresh", action: #selector(refreshAction), keyEquivalent: "r")
        refresh.target = self
        menu.addItem(refresh)
        menu.addItem(NSMenuItem(title: "Quit Desktop Navigator", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    @objc private func menuItemSelected(_ sender: NSMenuItem) {
        guard let target = sender.representedObject as? SpaceTarget else { return }
        controller.switchTo(displayIndex: target.displayIndex, spaceIndex: target.spaceIndex)
    }

    @objc private func enableShortcutsAction() {
        let count = max(controller.displays.first?.spaces.count ?? 0, 4)
        HotkeySetup.enable(count: min(count, 9))
    }

    @objc private func openMissionControlPrefs() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.keyboard?Shortcuts") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func refreshAction() { controller.refresh() }
}
