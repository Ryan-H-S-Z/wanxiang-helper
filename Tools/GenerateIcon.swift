import AppKit

// Vector-drawn app icon; run from wanxiang-helper with: swift Tools/GenerateIcon.swift
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconset = root.appendingPathComponent("Resources/AppIcon.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: r, green: g, blue: b, alpha: a)
}
func rounded(_ rect: NSRect, _ radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}
func render(_ pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx
    ctx.imageInterpolation = .high
    let transform = NSAffineTransform(); transform.scale(by: CGFloat(pixels) / 1024); transform.concat()
    let tile = rounded(NSRect(x: 80, y: 80, width: 864, height: 864), 194)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
    shadow.shadowBlurRadius = 23; shadow.shadowOffset = NSSize(width: 0, height: -12); shadow.set()
    color(0.04, 0.09, 0.12).setFill(); tile.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(starting: color(0.12, 0.23, 0.25), ending: color(0.025, 0.055, 0.09))!.draw(in: tile, angle: -90)
    color(0.44, 0.84, 0.74, 0.2).setStroke(); tile.lineWidth = 3; tile.stroke()
    // Quiet board intersections remain visible around the central playing piece.
    let grid = NSBezierPath()
    for value in [CGFloat(288), 512, 736] {
        grid.move(to: NSPoint(x: 224, y: value)); grid.line(to: NSPoint(x: 800, y: value))
        grid.move(to: NSPoint(x: value, y: 224)); grid.line(to: NSPoint(x: value, y: 800))
    }
    color(0.43, 0.85, 0.72, 0.19).setStroke(); grid.lineWidth = 8; grid.lineCapStyle = .round; grid.stroke()
    for x in [CGFloat(288), 736] {
        for y in [CGFloat(288), 736] {
            color(0.43, 0.85, 0.72, 0.45).setFill()
            NSBezierPath(ovalIn: NSRect(x: x-11, y: y-11, width: 22, height: 22)).fill()
        }
    }
    let stone = NSBezierPath(ovalIn: NSRect(x: 269, y: 254, width: 486, height: 486))
    NSGraphicsContext.saveGraphicsState()
    let stoneShadow = NSShadow(); stoneShadow.shadowColor = NSColor.black.withAlphaComponent(0.5)
    stoneShadow.shadowBlurRadius = 30; stoneShadow.shadowOffset = NSSize(width: 0, height: -20); stoneShadow.set()
    color(0.3, 0.65, 0.56).setFill(); stone.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(starting: color(0.66, 0.96, 0.84), ending: color(0.25, 0.73, 0.60))!.draw(in: stone, angle: -90)
    let rim = NSBezierPath(ovalIn: NSRect(x: 292, y: 277, width: 440, height: 440))
    color(0.06, 0.24, 0.23, 0.4).setStroke(); rim.lineWidth = 7; rim.stroke()
    let glyph = "棋" as NSString
    let font = NSFont(name: "PingFangSC-Semibold", size: 285) ?? NSFont.boldSystemFont(ofSize: 285)
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color(0.035, 0.18, 0.18)]
    let size = glyph.size(withAttributes: attrs)
    glyph.draw(at: NSPoint(x: 512-size.width/2, y: 497-size.height/2), withAttributes: attrs)
    // Gold promotion chevron connects the chess mark to the upgrade helper.
    let badge = rounded(NSRect(x: 697, y: 675, width: 136, height: 136), 42)
    color(0.98, 0.79, 0.39).setFill(); badge.fill()
    let up = NSBezierPath(); up.move(to: NSPoint(x: 731, y: 731)); up.line(to: NSPoint(x: 765, y: 765)); up.line(to: NSPoint(x: 799, y: 731))
    up.lineWidth = 15; up.lineCapStyle = .round; up.lineJoinStyle = .round
    color(0.16, 0.22, 0.2).setStroke(); up.stroke()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}
for size in [16, 32, 128, 256, 512] {
    try render(size).write(to: iconset.appendingPathComponent("icon_\(size)x\(size).png"))
    try render(size * 2).write(to: iconset.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
try render(1024).write(to: root.appendingPathComponent("Resources/AppIcon.png"))
