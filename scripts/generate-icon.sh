#!/usr/bin/env bash
# Generate App/AppIcon.icns from a programmatically-drawn design.
#
# This is a placeholder icon: dark rounded-square background with 4 white
# rectangles representing desktops, the second one filled. Replace
# App/AppIcon.icns with a properly designed one when you have one.

set -euo pipefail
cd "$(dirname "$0")/.."

ICONSET="build/AppIcon.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"

echo "==> Drawing icon at each required size..."

# All 10 iconset entries: (filename suffix, pixel dimension)
swift - "$ICONSET" <<'SWIFT'
import AppKit
import Foundation

let outDir = CommandLine.arguments[1]

// (filename suffix, pixel dimension)
let entries: [(String, Int)] = [
    ("16x16", 16),
    ("16x16@2x", 32),
    ("32x32", 32),
    ("32x32@2x", 64),
    ("128x128", 128),
    ("128x128@2x", 256),
    ("256x256", 256),
    ("256x256@2x", 512),
    ("512x512", 512),
    ("512x512@2x", 1024),
]

func drawIcon(pixels: Int) -> Data? {
    let size = NSSize(width: pixels, height: pixels)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    defer { NSGraphicsContext.restoreGraphicsState() }

    let rect = NSRect(origin: .zero, size: size)
    let s = CGFloat(pixels)

    // Background: dark blue-grey rounded square
    let cornerRadius = s * 0.18  // ~18% of icon side — standard macOS look
    let bg = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
    NSColor(srgbRed: 0.13, green: 0.18, blue: 0.28, alpha: 1).setFill()
    bg.fill()

    // 4 rectangles representing desktops, centered, 2nd one filled
    let dotCount = 4
    let dotW = s * 0.16          // each ~16% of icon width
    let dotH = dotW * 9 / 16     // 16:9 ratio matching the menu bar rects
    let dotSpacing = s * 0.035   // gap between rectangles
    let totalWidth = CGFloat(dotCount) * dotW + CGFloat(dotCount - 1) * dotSpacing
    let startX = (s - totalWidth) / 2
    let y = (s - dotH) / 2
    let stroke = max(1, s * 0.012)   // proportional stroke width

    for i in 0..<dotCount {
        let dotRect = NSRect(
            x: startX + CGFloat(i) * (dotW + dotSpacing),
            y: y,
            width: dotW,
            height: dotH
        )
        let cornerR = dotH * 0.12
        let path = NSBezierPath(roundedRect: dotRect, xRadius: cornerR, yRadius: cornerR)
        if i == 1 {
            NSColor.white.setFill()
            path.fill()
        } else {
            NSColor.white.setStroke()
            path.lineWidth = stroke
            path.stroke()
        }
    }

    return rep.representation(using: .png, properties: [:])
}

for (suffix, pixels) in entries {
    guard let data = drawIcon(pixels: pixels) else {
        print("Failed to render icon_\(suffix).png", to: &StandardError.stream)
        exit(1)
    }
    let path = "\(outDir)/icon_\(suffix).png"
    try? data.write(to: URL(fileURLWithPath: path))
    print("  drew icon_\(suffix).png (\(pixels)x\(pixels))")
}

struct StandardError: TextOutputStream {
    static var stream = StandardError()
    mutating func write(_ s: String) { FileHandle.standardError.write(Data(s.utf8)) }
}
SWIFT

echo
echo "==> Packaging as App/AppIcon.icns..."
iconutil -c icns -o App/AppIcon.icns "$ICONSET"

echo
echo "==> Done."
ls -la App/AppIcon.icns
