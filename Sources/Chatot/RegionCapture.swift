import AppKit
import ChatotCore

/// Interactive screen-region capture using the system `screencapture` tool (handles the crosshair UI and permissions).
enum RegionCapture {
    static func capture(_ completion: @escaping (Data?) -> Void) {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("chatot-capture-\(UUID().uuidString).png").path
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        p.arguments = ["-i", "-x", "-t", "png", path]
        p.terminationHandler = { _ in
            defer { try? FileManager.default.removeItem(atPath: path) }
            guard let data = FileManager.default.contents(atPath: path), !data.isEmpty else { completion(nil); return }
            completion(downscale(data, maxSide: 1600) ?? data)
        }
        do { try p.run() } catch { Log.error("screencapture failed: \(error)"); completion(nil) }
    }

    /// Keep requests small: long side capped, re-encoded as PNG.
    static func downscale(_ data: Data, maxSide: CGFloat) -> Data? {
        guard let img = NSImage(data: data), let rep = NSBitmapImageRep(data: data) else { return nil }
        let w = CGFloat(rep.pixelsWide), h = CGFloat(rep.pixelsHigh)
        let scale = min(1, maxSide / max(w, h))
        if scale >= 1 { return nil }
        let size = NSSize(width: floor(w * scale), height: floor(h * scale))
        guard let out = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
        out.size = size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: out)
        img.draw(in: NSRect(origin: .zero, size: size), from: .zero, operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        return out.representation(using: .png, properties: [:])
    }
}
