import AppKit

enum DotsRenderer {
    static let dotHeight: CGFloat = 18
    static let dotWidth: CGFloat = dotHeight * 16.0 / 9.0   // 32pt — 16:9 width:height
    static let dotSpacing: CGFloat = 4
    static let displaySpacing: CGFloat = 9
    static let sidePadding: CGFloat = 4
    static let height: CGFloat = 22

    static let expandGap: CGFloat = 8
    static let expandWidth: CGFloat = 11
    static let expandHeight: CGFloat = 11
    static let expandTipSize: CGFloat = 5   // size of each corner arrowhead

    enum Hit {
        case dot(display: Int, space: Int)
        case missionControl
    }

    private static func size(for displays: [DisplayInfo]) -> NSSize {
        let totalDots = displays.reduce(0) { $0 + $1.spaces.count }
        let trailing = expandGap + expandWidth
        guard totalDots > 0 else { return NSSize(width: 14 + trailing, height: height) }
        let dotsWidth = CGFloat(totalDots) * dotWidth
        let withinDisplaySpacing = displays.reduce(0.0) { acc, d in
            acc + CGFloat(max(0, d.spaces.count - 1)) * dotSpacing
        }
        let betweenDisplays = CGFloat(max(0, displays.count - 1)) * displaySpacing
        return NSSize(
            width: sidePadding * 2 + dotsWidth + withinDisplaySpacing + betweenDisplays + trailing,
            height: height
        )
    }

    static func render(displays: [DisplayInfo], activeID: CGSSpaceID) -> NSImage {
        let size = size(for: displays)
        let image = NSImage(size: size, flipped: false) { _ in
            var x: CGFloat = sidePadding
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

            // "Expand" icon (Mission Control trigger) at the trailing end: two
            // arrowheads on opposite corners pointing outward, the standard
            // macOS visual for full-screen / expand actions.
            let ax = x + expandGap
            let ay = (size.height - expandHeight) / 2
            let t = expandTipSize

            // Top-left arrowhead (points up-left)
            let topLeft = NSBezierPath()
            topLeft.move(to: NSPoint(x: ax, y: ay + expandHeight))
            topLeft.line(to: NSPoint(x: ax + t, y: ay + expandHeight))
            topLeft.line(to: NSPoint(x: ax, y: ay + expandHeight - t))
            topLeft.close()

            // Bottom-right arrowhead (points down-right)
            let botRight = NSBezierPath()
            botRight.move(to: NSPoint(x: ax + expandWidth, y: ay))
            botRight.line(to: NSPoint(x: ax + expandWidth - t, y: ay))
            botRight.line(to: NSPoint(x: ax + expandWidth, y: ay + t))
            botRight.close()

            NSColor.black.setFill()
            topLeft.fill()
            botRight.fill()
            return true
        }
        image.isTemplate = true
        return image
    }

    static func hitTest(x: CGFloat, in displays: [DisplayInfo]) -> Hit? {
        var cursor: CGFloat = sidePadding
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
        // Anything past the last dot lands in the expand-icon zone (forgiving hit area).
        if x >= cursor + expandGap / 2 {
            return .missionControl
        }
        return nil
    }
}
