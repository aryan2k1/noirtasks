// Generates AppIcon.icns: a pure-white checkbox on a jet-black rounded square.
// Run:  swift scripts/make-icon.swift   (from the project root)
import AppKit

func draw(size px: Int) -> Data? {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { return nil }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let s = CGFloat(px) / 1024.0
    let t = NSAffineTransform()
    t.scale(by: s)
    t.concat()

    // Jet-black rounded square with the standard macOS icon margin.
    let bg = NSBezierPath(
        roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824),
        xRadius: 185, yRadius: 185
    )
    NSColor.black.setFill()
    bg.fill()

    NSColor.white.setStroke()

    // Checkbox outline.
    let box = NSBezierPath(
        roundedRect: NSRect(x: 292, y: 292, width: 440, height: 440),
        xRadius: 88, yRadius: 88
    )
    box.lineWidth = 52
    box.stroke()

    // Checkmark.
    let check = NSBezierPath()
    check.move(to: NSPoint(x: 386, y: 516))
    check.line(to: NSPoint(x: 486, y: 412))
    check.line(to: NSPoint(x: 682, y: 636))
    check.lineWidth = 70
    check.lineCapStyle = .round
    check.lineJoinStyle = .round
    check.stroke()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

let iconset = "AppIcon.iconset"
try? FileManager.default.removeItem(atPath: iconset)
try! FileManager.default.createDirectory(atPath: iconset, withIntermediateDirectories: true)

let entries: [(String, Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024)
]

for (name, px) in entries {
    guard let data = draw(size: px) else {
        fputs("failed to render \(name)\n", stderr)
        exit(1)
    }
    try! data.write(to: URL(fileURLWithPath: "\(iconset)/\(name)"))
}
print("Wrote \(iconset)")
