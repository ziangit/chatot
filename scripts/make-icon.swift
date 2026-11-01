// Renders the app icon (rounded square, speech bubble, 译) into an .icns. Usage: swift scripts/make-icon.swift out.icns
import AppKit
let out = CommandLine.arguments[1]
let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("chatot-icon-\(UUID().uuidString).iconset")
try! FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
func render(_ px: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px)
    let inset = s * 0.08
    let bg = NSBezierPath(roundedRect: NSRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset), xRadius: s * 0.2, yRadius: s * 0.2)
    NSGradient(starting: NSColor(calibratedRed: 0.20, green: 0.45, blue: 0.95, alpha: 1), ending: NSColor(calibratedRed: 0.10, green: 0.25, blue: 0.65, alpha: 1))!.draw(in: bg, angle: -90)
    // speech bubble
    let b = NSRect(x: s * 0.2, y: s * 0.32, width: s * 0.6, height: s * 0.42)
    let bubble = NSBezierPath(roundedRect: b, xRadius: s * 0.1, yRadius: s * 0.1)
    bubble.move(to: NSPoint(x: s * 0.36, y: b.minY + 1)); bubble.line(to: NSPoint(x: s * 0.30, y: s * 0.22)); bubble.line(to: NSPoint(x: s * 0.48, y: b.minY + 1)); bubble.close()
    NSColor.white.setFill(); bubble.fill()
    let para = NSMutableParagraphStyle(); para.alignment = .center
    let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: s * 0.30, weight: .bold), .foregroundColor: NSColor(calibratedRed: 0.12, green: 0.30, blue: 0.75, alpha: 1), .paragraphStyle: para]
    ("译" as NSString).draw(in: NSRect(x: b.minX, y: b.minY + s * 0.035, width: b.width, height: b.height), withAttributes: attrs)
    NSGraphicsContext.restoreGraphicsState()
    return rep
}
for (name, px) in [("icon_16x16", 16), ("icon_16x16@2x", 32), ("icon_32x32", 32), ("icon_32x32@2x", 64), ("icon_128x128", 128), ("icon_128x128@2x", 256), ("icon_256x256", 256), ("icon_256x256@2x", 512), ("icon_512x512", 512), ("icon_512x512@2x", 1024)] {
    try! render(px).representation(using: .png, properties: [:])!.write(to: tmp.appendingPathComponent("\(name).png"))
}
let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil"); p.arguments = ["-c", "icns", tmp.path, "-o", out]
try! p.run(); p.waitUntilExit()
try? FileManager.default.removeItem(at: tmp)
print("wrote \(out), status \(p.terminationStatus)")
