// Renders the pixel-art Chatot app icon (.icns) and the menubar template icons.
// Usage: swift scripts/make-icon.swift build/AppIcon.icns build/MenuIcon.png build/MenuIcon@2x.png
import AppKit
let args = CommandLine.arguments
let icnsOut = args[1], menuOut = args[2], menu2xOut = args[3]

// 16×16 pixel Chatot facing left: K black head with music-note crest, Y beak/feet, W eye, B wings, G belly, R tail.
let grid = [
    "........KK......",
    "........K.K.....",
    ".......KK.......",
    "......KKKK......",
    ".....KKKKKK.....",
    "....KKWWKKKK....",
    ".YY.KKWKKKKK....",
    ".YYYKKKKKKBB....",
    "..YYKKKKBBBBB...",
    "....KGGGBBBBBB..",
    "....GGGGGBBBBBR.",
    "....GGGGGBBBBRR.",
    ".....GGGBBBBRRR.",
    "......GGGBBB..R.",
    ".......Y.Y......",
    "......YY.YY.....",
]
let palette: [Character: NSColor] = [
    "K": NSColor(red: 0.13, green: 0.13, blue: 0.16, alpha: 1),
    "Y": NSColor(red: 0.98, green: 0.78, blue: 0.20, alpha: 1),
    "W": NSColor.white,
    "B": NSColor(red: 0.27, green: 0.55, blue: 0.92, alpha: 1),
    "G": NSColor(red: 0.55, green: 0.85, blue: 0.55, alpha: 1),
    "R": NSColor(red: 0.90, green: 0.35, blue: 0.30, alpha: 1),
]

func bitmap(_ px: Int) -> NSBitmapImageRep {
    NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
}

/// App icon: cream rounded square, Chatot centred, nearest-neighbour pixels.
func renderApp(_ px: Int) -> NSBitmapImageRep {
    let rep = bitmap(px)
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .none
    let s = CGFloat(px), inset = s * 0.08
    let bg = NSBezierPath(roundedRect: NSRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset), xRadius: s * 0.2, yRadius: s * 0.2)
    NSColor(red: 1.0, green: 0.96, blue: 0.86, alpha: 1).setFill(); bg.fill()
    let cell = floor(s * 0.72 / 16)
    let ox = (s - cell * 16) / 2, oy = (s - cell * 16) / 2
    for (r, row) in grid.enumerated() {
        for (c, ch) in row.enumerated() {
            guard let color = palette[ch] else { continue }
            color.setFill()
            NSRect(x: ox + CGFloat(c) * cell, y: oy + CGFloat(15 - r) * cell, width: cell, height: cell).fill()
        }
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

/// Menubar template: the silhouette in black, 1 grid px = `cell` device px, 1 px margin.
func renderMenu(_ cell: Int) -> NSBitmapImageRep {
    let px = 18 * cell
    let rep = bitmap(px)
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSColor.black.setFill()
    for (r, row) in grid.enumerated() {
        for (c, ch) in row.enumerated() where ch != "." {
            // Eye and belly lighter so the silhouette still reads as a bird in monochrome.
            NSColor.black.withAlphaComponent(ch == "W" ? 0.0 : (ch == "G" ? 0.55 : 1)).setFill()
            NSRect(x: (1 + c) * cell, y: (1 + 15 - r) * cell, width: cell, height: cell).fill()
        }
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("chatot-icon-\(UUID().uuidString).iconset")
try! FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
for (name, px) in [("icon_16x16", 16), ("icon_16x16@2x", 32), ("icon_32x32", 32), ("icon_32x32@2x", 64), ("icon_128x128", 128), ("icon_128x128@2x", 256), ("icon_256x256", 256), ("icon_256x256@2x", 512), ("icon_512x512", 512), ("icon_512x512@2x", 1024)] {
    try! renderApp(px).representation(using: .png, properties: [:])!.write(to: tmp.appendingPathComponent("\(name).png"))
}
let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil"); p.arguments = ["-c", "icns", tmp.path, "-o", icnsOut]
try! p.run(); p.waitUntilExit()
try? FileManager.default.removeItem(at: tmp)
try! renderMenu(1).representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: menuOut))
try! renderMenu(2).representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: menu2xOut))
print("wrote \(icnsOut) and menubar icons, status \(p.terminationStatus)")
