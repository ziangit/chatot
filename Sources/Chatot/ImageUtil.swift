import AppKit

enum ImageUtil {
    /// PNG data from a pasteboard holding an image or an image file URL.
    static func imageData(from pb: NSPasteboard) -> Data? {
        if let d = pb.data(forType: .png) { return d }
        if let d = pb.data(forType: .tiff), let rep = NSBitmapImageRep(data: d), let png = rep.representation(using: .png, properties: [:]) { return png }
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], let u = urls.first,
           ["png", "jpg", "jpeg", "gif", "webp", "tiff", "heic"].contains(u.pathExtension.lowercased()),
           let img = NSImage(contentsOf: u), let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) { return png }
        return nil
    }

    /// Keep requests small: long side capped, re-encoded as PNG. Returns nil when no downscale is needed.
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
