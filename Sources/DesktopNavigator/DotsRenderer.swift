import AppKit

enum DotsRenderer {
    static let dotHeight: CGFloat = 18
    static let dotWidth: CGFloat = dotHeight * 16.0 / 9.0   // 32pt — 16:9 width:height
    static let dotSpacing: CGFloat = 4
    static let displaySpacing: CGFloat = 9
    static let sidePadding: CGFloat = 4
    static let height: CGFloat = 22

    static let cameraSlot: CGFloat = dotWidth   // same footprint as a desktop rect (32pt)
    static let cameraSize: CGFloat = 16         // SF Symbol icon size, centered in the slot
    static let cameraGap: CGFloat = 8           // gap between camera slot and first rectangle

    static let expandGap: CGFloat = 8    // gap between last rectangle and expand icon
    static let expandWidth: CGFloat = dotWidth     // match desktop rects (32pt)
    static let expandHeight: CGFloat = dotHeight   // match desktop rects (18pt)
    static let expandArrowHeadWidth: CGFloat = 14
    static let expandArrowHeadHeight: CGFloat = 7
    static let expandArrowShaftWidth: CGFloat = 5
    static let expandArrowShaftHeight: CGFloat = 6

    enum Hit {
        case dot(display: Int, space: Int)
        case screenshot
        case missionControl
    }

    private static func size(for displays: [DisplayInfo]) -> NSSize {
        let totalDots = displays.reduce(0) { $0 + $1.spaces.count }
        let leading = cameraSlot + cameraGap
        let trailing = expandGap + expandWidth
        guard totalDots > 0 else {
            return NSSize(width: sidePadding * 2 + leading + 14 + trailing, height: height)
        }
        let dotsWidth = CGFloat(totalDots) * dotWidth
        let withinDisplaySpacing = displays.reduce(0.0) { acc, d in
            acc + CGFloat(max(0, d.spaces.count - 1)) * dotSpacing
        }
        let betweenDisplays = CGFloat(max(0, displays.count - 1)) * displaySpacing
        return NSSize(
            width: sidePadding * 2 + leading + dotsWidth + withinDisplaySpacing + betweenDisplays + trailing,
            height: height
        )
    }

    static func render(displays: [DisplayInfo], activeID: CGSSpaceID) -> NSImage {
        let size = size(for: displays)
        let image = NSImage(size: size, flipped: false) { _ in
            var x: CGFloat = sidePadding

            // Camera (selectable-area screenshot to clipboard) — centered in a
            // slot the same width as a desktop rectangle so the menu bar reads
            // as three equal-footprint groups: action, context, action.
            let cameraX = x + (cameraSlot - cameraSize) / 2
            let cameraY = (size.height - cameraSize) / 2
            if let cam = NSImage(systemSymbolName: "camera", accessibilityDescription: nil) {
                let config = NSImage.SymbolConfiguration(pointSize: cameraSize, weight: .regular)
                if let configured = cam.withSymbolConfiguration(config) {
                    configured.draw(in: NSRect(x: cameraX, y: cameraY, width: configured.size.width, height: configured.size.height))
                }
            }
            x += cameraSlot + cameraGap

            // Rectangles for each desktop.
            let y = (size.height - dotHeight) / 2
            for (di, display) in displays.enumerated() {
                for (si, space) in display.spaces.enumerated() {
                    let rect = NSRect(x: x, y: y, width: dotWidth, height: dotHeight)
                    let path = NSBezierPath(rect: rect.insetBy(dx: 0.5, dy: 0.5))
                    if space.id == activeID {
                        NSColor.black.setFill()
                        path.fill()
                    } else {
                        NSColor.black.setStroke()
                        path.lineWidth = 1
                        path.stroke()
                    }
                    x += dotWidth
                    if si < display.spaces.count - 1 { x += dotSpacing }
                }
                if di < displays.count - 1 { x += displaySpacing }
            }

            // Expand icon (Mission Control trigger): a dotted-border rectangle
            // matching the desktop rect dimensions, with a single big up-arrow
            // centered inside. The dotted border distinguishes it from the
            // solid-bordered desktop rects while keeping the layout rhythm.
            let ax = x + expandGap
            let ay = (size.height - expandHeight) / 2

            let outerRect = NSRect(x: ax, y: ay, width: expandWidth, height: expandHeight)
            let outerPath = NSBezierPath(rect: outerRect.insetBy(dx: 0.5, dy: 0.5))
            outerPath.lineWidth = 1
            outerPath.lineCapStyle = .round
            outerPath.setLineDash([1, 3], count: 2, phase: 0)
            NSColor.black.setStroke()
            outerPath.stroke()

            // Centered up-arrow (triangular head + rectangular shaft) drawn as
            // one closed path. Single-path means no anti-alias seam where the
            // arrowhead meets the shaft.
            let arrowTotalHeight = expandArrowHeadHeight + expandArrowShaftHeight
            let centerX = ax + expandWidth / 2
            let arrowBottom = ay + (expandHeight - arrowTotalHeight) / 2
            let shaftTop = arrowBottom + expandArrowShaftHeight
            let arrowTop = arrowBottom + arrowTotalHeight
            let shaftLeft = centerX - expandArrowShaftWidth / 2
            let shaftRight = centerX + expandArrowShaftWidth / 2
            let headLeft = centerX - expandArrowHeadWidth / 2
            let headRight = centerX + expandArrowHeadWidth / 2

            let upArrow = NSBezierPath()
            upArrow.move(to: NSPoint(x: shaftLeft, y: arrowBottom))
            upArrow.line(to: NSPoint(x: shaftLeft, y: shaftTop))
            upArrow.line(to: NSPoint(x: headLeft, y: shaftTop))
            upArrow.line(to: NSPoint(x: centerX, y: arrowTop))
            upArrow.line(to: NSPoint(x: headRight, y: shaftTop))
            upArrow.line(to: NSPoint(x: shaftRight, y: shaftTop))
            upArrow.line(to: NSPoint(x: shaftRight, y: arrowBottom))
            upArrow.close()
            NSColor.black.setFill()
            upArrow.fill()
            return true
        }
        image.isTemplate = true
        return image
    }

    static func hitTest(x: CGFloat, in displays: [DisplayInfo]) -> Hit? {
        // Camera owns the leading slot — the entire 32pt-wide region plus half
        // the gap to the first rectangle.
        let cameraEnd = sidePadding + cameraSlot + cameraGap / 2
        if x < cameraEnd { return .screenshot }

        var cursor: CGFloat = sidePadding + cameraSlot + cameraGap
        for (di, display) in displays.enumerated() {
            for (si, _) in display.spaces.enumerated() {
                let hitStart = cursor - dotSpacing / 2
                let hitEnd = cursor + dotWidth + dotSpacing / 2
                if x >= hitStart && x < hitEnd { return .dot(display: di, space: si) }
                cursor += dotWidth
                if si < display.spaces.count - 1 { cursor += dotSpacing }
            }
            if di < displays.count - 1 { cursor += displaySpacing }
        }
        // Anything past the last rectangle lands in the expand zone.
        if x >= cursor + expandGap / 2 {
            return .missionControl
        }
        return nil
    }
}
