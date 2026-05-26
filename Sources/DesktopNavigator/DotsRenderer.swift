import AppKit

enum DotsRenderer {
    static let dotHeight: CGFloat = 18
    static let dotWidth: CGFloat = dotHeight * 16.0 / 9.0   // 32pt — 16:9 width:height
    static let dotSpacing: CGFloat = 4
    static let displaySpacing: CGFloat = 9
    static let sidePadding: CGFloat = 4
    static let height: CGFloat = 22

    static let chevronWidth: CGFloat = 9
    static let chevronHeight: CGFloat = 5
    static let chevronPadding: CGFloat = 4

    private static func dotsSize(for displays: [DisplayInfo]) -> NSSize {
        let totalDots = displays.reduce(0) { $0 + $1.spaces.count }
        guard totalDots > 0 else { return NSSize(width: 14, height: height) }
        let dotsWidth = CGFloat(totalDots) * dotWidth
        let withinDisplaySpacing = displays.reduce(0.0) { acc, d in
            acc + CGFloat(max(0, d.spaces.count - 1)) * dotSpacing
        }
        let betweenDisplays = CGFloat(max(0, displays.count - 1)) * displaySpacing
        return NSSize(
            width: sidePadding * 2 + dotsWidth + withinDisplaySpacing + betweenDisplays,
            height: height
        )
    }

    static func renderDots(displays: [DisplayInfo], activeID: CGSSpaceID) -> NSImage {
        let size = dotsSize(for: displays)
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
            return true
        }
        image.isTemplate = true
        return image
    }

    static func renderChevron() -> NSImage {
        let size = NSSize(width: chevronWidth + chevronPadding * 2, height: height)
        let image = NSImage(size: size, flipped: false) { _ in
            let cx = chevronPadding
            let cy = (size.height - chevronHeight) / 2
            let tri = NSBezierPath()
            tri.move(to: NSPoint(x: cx, y: cy + chevronHeight))
            tri.line(to: NSPoint(x: cx + chevronWidth, y: cy + chevronHeight))
            tri.line(to: NSPoint(x: cx + chevronWidth / 2, y: cy))
            tri.close()
            NSColor.black.setFill()
            tri.fill()
            return true
        }
        image.isTemplate = true
        return image
    }

    /// Maps an x coordinate (in image space) to the dot under it.
    static func dotAt(x: CGFloat, in displays: [DisplayInfo]) -> (display: Int, space: Int)? {
        var cursor: CGFloat = sidePadding
        for (di, display) in displays.enumerated() {
            for (si, _) in display.spaces.enumerated() {
                let hitStart = cursor - dotSpacing / 2
                let hitEnd = cursor + dotWidth + dotSpacing / 2
                if x >= hitStart && x < hitEnd { return (di, si) }
                cursor += dotWidth
                if si < display.spaces.count - 1 { cursor += dotSpacing }
            }
            if di < displays.count - 1 { cursor += displaySpacing }
        }
        return nil
    }
}
