import AppKit
import Foundation

// Rasterizes the app icon (matching AppIcon.svg) at every .iconset size using
// AppKit — no external SVG rasterizer needed. Usage:
//   swiftc RenderIcon.swift -o rendericon && ./rendericon path/to/AppIcon.iconset

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

let entries: [(String, Int)] = [
    ("icon_16x16", 16),   ("icon_16x16@2x", 32),
    ("icon_32x32", 32),   ("icon_32x32@2x", 64),
    ("icon_128x128", 128),("icon_128x128@2x", 256),
    ("icon_256x256", 256),("icon_256x256@2x", 512),
    ("icon_512x512", 512),("icon_512x512@2x", 1024),
]

func render(_ px: Int) -> Data {
    let s = CGFloat(px)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                               isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: s, height: s)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // White squircle background.
    let m = s * 0.045
    let inner = NSRect(x: m, y: m, width: s - 2 * m, height: s - 2 * m)
    let corner = (s - 2 * m) * 0.2237
    NSColor.white.setFill()
    NSBezierPath(roundedRect: inner, xRadius: corner, yRadius: corner).fill()

    let c = NSPoint(x: s / 2, y: s / 2)
    let R = (s - 2 * m) / 2 * 0.72

    // Dial ring.
    let ring = NSBezierPath(ovalIn: NSRect(x: c.x - R, y: c.y - R, width: 2 * R, height: 2 * R))
    NSColor(white: 0, alpha: 0.10).setStroke()
    ring.lineWidth = max(1, s * 0.012)
    ring.stroke()

    // Red wedge — 60% revolution, counterclockwise from 12 o'clock (AppKit is y-up).
    let f: CGFloat = 0.6
    let start: CGFloat = 90
    let end: CGFloat = 90 + f * 360
    let wedge = NSBezierPath()
    wedge.move(to: c)
    wedge.line(to: NSPoint(x: c.x + R * cos(start * CGFloat.pi / 180),
                           y: c.y + R * sin(start * CGFloat.pi / 180)))
    wedge.appendArc(withCenter: c, radius: R, startAngle: start, endAngle: end, clockwise: false)
    wedge.close()
    NSColor(srgbRed: 0.90, green: 0.16, blue: 0.16, alpha: 1).setFill()
    wedge.fill()

    // Hub.
    let hubR = R * 0.06
    NSColor(white: 0, alpha: 0.85).setFill()
    NSBezierPath(ovalIn: NSRect(x: c.x - hubR, y: c.y - hubR, width: 2 * hubR, height: 2 * hubR)).fill()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for (name, px) in entries {
    let url = URL(fileURLWithPath: outDir).appendingPathComponent("\(name).png")
    try! render(px).write(to: url)
    print("wrote \(name).png")
}
