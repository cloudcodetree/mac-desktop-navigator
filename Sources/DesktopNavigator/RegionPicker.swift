import AppKit

/// Drag-to-select screenshot picker drawn by this app.
///
/// Replaces `screencapture -i`, whose overlay and crosshair belong to a system
/// agent that some remote-desktop tools cannot display or drive (the cursor is
/// invisible and the remote pointer ends the selection). This overlay is an
/// ordinary window with ordinary mouse handling, so it works wherever a click
/// on the menu bar works.
final class RegionPicker {
    enum Geometry {
        /// Normalized rectangle between two drag points, grown to whole points.
        static func selection(from a: CGPoint, to b: CGPoint) -> CGRect {
            let minX = min(a.x, b.x).rounded(.down)
            let minY = min(a.y, b.y).rounded(.down)
            let maxX = max(a.x, b.x).rounded(.up)
            let maxY = max(a.y, b.y).rounded(.up)
            return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        }

        static let minimumSide: CGFloat = 4

        /// A click with no real drag is a cancel, not a capture.
        static func isTooSmall(_ rect: CGRect) -> Bool {
            rect.width < minimumSide || rect.height < minimumSide
        }

        /// Cocoa global coordinates (origin at the primary display's bottom-left)
        /// to CoreGraphics global coordinates (origin at its top-left), which is
        /// what `screencapture -R` expects. Works for every display because both
        /// systems share the primary display as their origin.
        static func captureRect(cocoa rect: CGRect, primaryScreenHeight height: CGFloat) -> CGRect {
            CGRect(x: rect.minX, y: height - rect.maxY, width: rect.width, height: rect.height)
        }
    }

    private var panels: [OverlayPanel] = []
    private var completion: ((CGRect?) -> Void)?

    /// Shows the overlay on every display. Calls back with the selection in
    /// Cocoa screen coordinates, or nil if the user cancelled.
    func begin(completion: @escaping (CGRect?) -> Void) {
        guard panels.isEmpty else { return }   // already picking
        self.completion = completion
        for screen in NSScreen.screens {
            let panel = OverlayPanel(screen: screen)
            panel.onSelect = { [weak self] rect in self?.finish(with: rect) }
            panel.onCancel = { [weak self] in self?.finish(with: nil) }
            panel.orderFrontRegardless()
            panels.append(panel)
        }
        panels.first?.makeKey()
    }

    private func finish(with rect: CGRect?) {
        panels.forEach { $0.orderOut(nil) }
        panels.removeAll()
        let completion = self.completion
        self.completion = nil
        // Give the window server a moment to drop the overlay before the
        // capture reads the screen, or the dimming ends up in the image.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { completion?(rect) }
    }

    /// Captures a region (Cocoa screen coordinates) to the clipboard.
    static func capture(cocoaRect: CGRect) {
        guard let primary = NSScreen.screens.first else { return }
        let r = Geometry.captureRect(cocoa: cocoaRect, primaryScreenHeight: primary.frame.height)
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        task.arguments = ["-c", "-R", "\(Int(r.minX)),\(Int(r.minY)),\(Int(r.width)),\(Int(r.height))"]
        try? task.run()
    }

    // MARK: - Overlay window

    private final class OverlayPanel: NSPanel {
        var onSelect: ((CGRect) -> Void)?
        var onCancel: (() -> Void)?

        init(screen: NSScreen) {
            super.init(
                contentRect: screen.frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
            isOpaque = false
            backgroundColor = .clear
            hasShadow = false
            ignoresMouseEvents = false
            acceptsMouseMovedEvents = true
            isReleasedWhenClosed = false
            collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

            let view = OverlayView(frame: NSRect(origin: .zero, size: screen.frame.size))
            view.onSelect = { [weak self] rect in
                guard let self else { return }
                self.onSelect?(self.convertToScreen(rect))
            }
            view.onCancel = { [weak self] in self?.onCancel?() }
            contentView = view
            makeFirstResponder(view)
        }

        // A non-activating panel may take key focus without activating the app,
        // which is how Escape reaches us while we stay a background app.
        override var canBecomeKey: Bool { true }
    }

    private final class OverlayView: NSView {
        var onSelect: ((CGRect) -> Void)?
        var onCancel: (() -> Void)?
        private var start: CGPoint?
        private var current: CGPoint?
        /// Last known pointer position, for the crosshair we draw ourselves.
        /// The real cursor shape is invisible over most remote desktop tools.
        private var pointer: CGPoint?
        private var trackingArea: NSTrackingArea?

        override var acceptsFirstResponder: Bool { true }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override func resetCursorRects() { addCursorRect(bounds, cursor: .crosshair) }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let window {
                pointer = convert(window.convertPoint(fromScreen: NSEvent.mouseLocation), from: nil)
            }
        }

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            if let trackingArea { removeTrackingArea(trackingArea) }
            let area = NSTrackingArea(
                rect: bounds,
                options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                owner: self,
                userInfo: nil
            )
            addTrackingArea(area)
            trackingArea = area
        }

        override func mouseMoved(with event: NSEvent) {
            pointer = convert(event.locationInWindow, from: nil)
            needsDisplay = true
        }

        override func mouseEntered(with event: NSEvent) { mouseMoved(with: event) }

        override func mouseDown(with event: NSEvent) {
            start = convert(event.locationInWindow, from: nil)
            current = start
            pointer = start
            needsDisplay = true
        }

        override func mouseDragged(with event: NSEvent) {
            current = convert(event.locationInWindow, from: nil)
            pointer = current
            needsDisplay = true
        }

        override func mouseUp(with event: NSEvent) {
            guard let start else { return }
            let rect = Geometry.selection(from: start, to: convert(event.locationInWindow, from: nil))
            self.start = nil
            current = nil
            if Geometry.isTooSmall(rect) { onCancel?() } else { onSelect?(rect) }
        }

        override func keyDown(with event: NSEvent) {
            if event.keyCode == 53 { onCancel?() } else { super.keyDown(with: event) }
        }

        override func draw(_ dirtyRect: NSRect) {
            NSColor.black.withAlphaComponent(0.25).setFill()
            bounds.fill()

            if let start, let current {
                let rect = Geometry.selection(from: start, to: current)
                NSColor.clear.setFill()
                rect.fill(using: .copy)
                NSColor.white.setStroke()
                let outline = NSBezierPath(rect: rect.insetBy(dx: 0.5, dy: 0.5))
                outline.lineWidth = 1
                outline.stroke()
                drawLabel("\(Int(rect.width)) × \(Int(rect.height))",
                          anchoredAt: CGPoint(x: rect.maxX, y: rect.minY - 8), alignRight: true)
            } else {
                drawCrosshair()
            }

            drawLabel("Drag to select an area  ·  Esc to cancel",
                      anchoredAt: CGPoint(x: bounds.midX, y: bounds.maxY - 48), centered: true)
        }

        private func drawCrosshair() {
            guard let pointer else { return }
            let shadow = NSBezierPath()
            shadow.move(to: CGPoint(x: pointer.x + 1, y: bounds.minY))
            shadow.line(to: CGPoint(x: pointer.x + 1, y: bounds.maxY))
            shadow.move(to: CGPoint(x: bounds.minX, y: pointer.y - 1))
            shadow.line(to: CGPoint(x: bounds.maxX, y: pointer.y - 1))
            NSColor.black.withAlphaComponent(0.5).setStroke()
            shadow.lineWidth = 1
            shadow.stroke()

            let lines = NSBezierPath()
            lines.move(to: CGPoint(x: pointer.x, y: bounds.minY))
            lines.line(to: CGPoint(x: pointer.x, y: bounds.maxY))
            lines.move(to: CGPoint(x: bounds.minX, y: pointer.y))
            lines.line(to: CGPoint(x: bounds.maxX, y: pointer.y))
            NSColor.white.withAlphaComponent(0.9).setStroke()
            lines.lineWidth = 1
            lines.stroke()
        }

        /// White text on a dark pill. `anchoredAt` is the top-center when
        /// `centered`, the top-right when `alignRight`, else the top-left.
        private func drawLabel(_ text: String, anchoredAt anchor: CGPoint, centered: Bool = false, alignRight: Bool = false) {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
                .foregroundColor: NSColor.white,
            ]
            let string = NSAttributedString(string: text, attributes: attributes)
            let size = string.size()
            let padding = CGSize(width: 12, height: 6)
            var origin = CGPoint(x: anchor.x, y: anchor.y - size.height - padding.height * 2)
            if centered { origin.x -= size.width / 2 + padding.width }
            if alignRight { origin.x -= size.width + padding.width * 2 }
            let pill = CGRect(origin: origin, size: CGSize(width: size.width + padding.width * 2, height: size.height + padding.height * 2))
            NSColor.black.withAlphaComponent(0.65).setFill()
            NSBezierPath(roundedRect: pill, xRadius: 8, yRadius: 8).fill()
            string.draw(at: CGPoint(x: pill.minX + padding.width, y: pill.minY + padding.height))
        }
    }
}
