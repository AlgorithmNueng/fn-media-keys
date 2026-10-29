// Draws the app icon: `swift scripts/make-icon.swift` (run it from anywhere; AppKit only).
// Writes scripts/AppIcon.icns (copied into the app bundle by make-app.sh) and docs/icon.png (used
// by the README). Both outputs are committed, so building the app does not need to run this.
//
// Everything is drawn with paths, no fonts, so the icon is identical on every Mac. Each size is
// rendered at its own pixel size, not scaled down from one bitmap, so the small ones stay crisp.
import AppKit

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()

func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

// Strokes of "fn", centre lines in 1024-grid coordinates (origin top left). With the 64 wide
// stroke, the glyphs fill y 300...600 (baseline 600, x-height 420) and x 250...620.
let letters: CGPath = {
    let p = CGMutablePath()
    // f: stem with a rounded hook at the top right, and the crossbar
    p.move(to: CGPoint(x: 322, y: 568))
    p.addLine(to: CGPoint(x: 322, y: 410))
    p.addCurve(to: CGPoint(x: 392, y: 332), control1: CGPoint(x: 322, y: 367), control2: CGPoint(x: 353, y: 332))
    p.move(to: CGPoint(x: 282, y: 452))
    p.addLine(to: CGPoint(x: 366, y: 452))
    // n: stem, and an arch that comes down to the baseline
    p.move(to: CGPoint(x: 472, y: 568))
    p.addLine(to: CGPoint(x: 472, y: 452))
    p.move(to: CGPoint(x: 472, y: 484))
    p.addCurve(to: CGPoint(x: 530, y: 452), control1: CGPoint(x: 472, y: 462), control2: CGPoint(x: 498, y: 452))
    p.addCurve(to: CGPoint(x: 588, y: 510), control1: CGPoint(x: 562, y: 452), control2: CGPoint(x: 588, y: 478))
    p.addLine(to: CGPoint(x: 588, y: 568))
    return p
}()

// The play triangle: a sharp triangle stroked with a round join gives rounded corners.
// 84 tall inside plus 8 of stroke on each side is 100 tall; it sits a little right of the badge
// centre because a triangle looks centred when its middle, not its bounding box, is.
let play: CGPath = {
    let left: CGFloat = 662, half: CGFloat = 42, width = half * 2 * 0.866
    let p = CGMutablePath()
    p.move(to: CGPoint(x: left, y: 700 - half))
    p.addLine(to: CGPoint(x: left + width, y: 700))
    p.addLine(to: CGPoint(x: left, y: 700 + half))
    p.closeSubpath()
    return p
}()

func drawIcon(size: Int) -> CGImage {
    let ctx = CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let scale = CGFloat(size) / 1024
    ctx.translateBy(x: 0, y: CGFloat(size))
    ctx.scaleBy(x: scale, y: -scale)  // 1024 grid, origin top left

    // Tile. The shadow is not scaled by the transform above, so it is scaled here.
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -8 * scale), blur: 24 * scale, color: color(0x000000, alpha: 0.25))
    ctx.setFillColor(color(0xF5F5F7))
    ctx.addPath(CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil))
    ctx.fillPath()
    ctx.restoreGState()

    // 2 px border, drawn inside the tile edge
    ctx.setStrokeColor(color(0xD2D2D7))
    ctx.setLineWidth(2)
    ctx.addPath(CGPath(roundedRect: tile.insetBy(dx: 1, dy: 1), cornerWidth: 184, cornerHeight: 184, transform: nil))
    ctx.strokePath()

    ctx.setStrokeColor(color(0x1D1D1F))
    ctx.setLineWidth(64)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.addPath(letters)
    ctx.strokePath()

    // Badge
    ctx.setFillColor(color(0xFF6B2C))
    ctx.fillEllipse(in: CGRect(x: 590, y: 600, width: 200, height: 200))
    ctx.setFillColor(color(0xFFFFFF))
    ctx.setStrokeColor(color(0xFFFFFF))
    ctx.setLineWidth(16)
    ctx.addPath(play)
    ctx.drawPath(using: .fillStroke)

    return ctx.makeImage()!
}

func writePNG(size: Int, to url: URL) throws {
    let png = NSBitmapImageRep(cgImage: drawIcon(size: size)).representation(using: .png, properties: [:])!
    try png.write(to: url)
}

let fm = FileManager.default
let work = fm.temporaryDirectory.appendingPathComponent("make-icon-\(UUID().uuidString)")
defer { try? fm.removeItem(at: work) }
let iconset = work.appendingPathComponent("AppIcon.iconset")
try fm.createDirectory(at: iconset, withIntermediateDirectories: true)

for points in [16, 32, 128, 256, 512] {
    try writePNG(size: points, to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
    try writePNG(size: points * 2, to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}

let icns = root.appendingPathComponent("scripts/AppIcon.icns")
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", icns.path]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else { fatalError("iconutil failed (\(iconutil.terminationStatus))") }

try fm.createDirectory(at: root.appendingPathComponent("docs"), withIntermediateDirectories: true)
try writePNG(size: 256, to: root.appendingPathComponent("docs/icon.png"))
print("wrote \(icns.path) and docs/icon.png")
