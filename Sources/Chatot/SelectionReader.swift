import AppKit
import ApplicationServices
import ChatotCore

enum Selection { case text(String), image(Data), none }

/// Reads the current selection in the frontmost app: Accessibility first, simulated ⌘C as fallback.
enum SelectionReader {
    static func readSelection(_ completion: @escaping (Selection) -> Void) {
        let trusted = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
        if !trusted { Log.info("Accessibility not granted yet; prompting") }
        if let s = axSelectedText(), !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Log.info("selection via AX (\(s.count) chars)")
            completion(.text(s)); return
        }
        copyFallback(completion)
    }

    static func axSelectedText() -> String? {
        let system = AXUIElementCreateSystemWide()
        var focused: AnyObject?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success, let el = focused else { return nil }
        var sel: AnyObject?
        if AXUIElementCopyAttributeValue(el as! AXUIElement, kAXSelectedTextAttribute as CFString, &sel) == .success, let s = sel as? String { return s }
        return nil
    }

    /// Screen rect of the selected text in the focused element (Cocoa coordinates), when the app exposes it.
    static func axSelectionBounds() -> NSRect? {
        let system = AXUIElementCreateSystemWide()
        var focused: AnyObject?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success, let el = focused else { return nil }
        let elem = el as! AXUIElement
        var rangeVal: AnyObject?
        guard AXUIElementCopyAttributeValue(elem, kAXSelectedTextRangeAttribute as CFString, &rangeVal) == .success, let rv = rangeVal else { return nil }
        var range = CFRange()
        guard AXValueGetValue(rv as! AXValue, .cfRange, &range), range.length > 0 else { return nil }
        var boundsVal: AnyObject?
        guard AXUIElementCopyParameterizedAttributeValue(elem, kAXBoundsForRangeParameterizedAttribute as CFString, rv, &boundsVal) == .success, let bv = boundsVal else { return nil }
        var rect = CGRect.zero
        guard AXValueGetValue(bv as! AXValue, .cgRect, &rect), rect.width > 0, rect.height > 0 else { return nil }
        return flipped(rect)
    }

    /// Frame of the frontmost app's focused window (Cocoa coordinates).
    static func axFocusedWindowFrame() -> NSRect? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var win: AnyObject?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &win) == .success, let w = win else { return nil }
        var posV: AnyObject?, sizeV: AnyObject?
        guard AXUIElementCopyAttributeValue(w as! AXUIElement, kAXPositionAttribute as CFString, &posV) == .success,
              AXUIElementCopyAttributeValue(w as! AXUIElement, kAXSizeAttribute as CFString, &sizeV) == .success,
              let p = posV, let sz = sizeV else { return nil }
        var pt = CGPoint.zero, size = CGSize.zero
        guard AXValueGetValue(p as! AXValue, .cgPoint, &pt), AXValueGetValue(sz as! AXValue, .cgSize, &size), size.width > 0 else { return nil }
        return flipped(CGRect(origin: pt, size: size))
    }

    /// AX uses a top-left origin on the primary display; AppKit uses bottom-left.
    static func flipped(_ r: CGRect) -> NSRect {
        let h = NSScreen.screens.first?.frame.height ?? 0
        return NSRect(x: r.minX, y: h - r.maxY, width: r.width, height: r.height)
    }

    /// Simulate ⌘C, read the pasteboard, then restore its previous contents.
    static func copyFallback(_ completion: @escaping (Selection) -> Void) {
        let pb = NSPasteboard.general
        let before = pb.changeCount
        let saved = pb.pasteboardItems?.compactMap { item -> NSPasteboardItem? in
            let copy = NSPasteboardItem()
            for t in item.types { if let d = item.data(forType: t) { copy.setData(d, forType: t) } }
            return copy
        } ?? []
        let src = CGEventSource(stateID: .combinedSessionState)
        let down = CGEvent(keyboardEventSource: src, virtualKey: 8, keyDown: true)   // C
        let up = CGEvent(keyboardEventSource: src, virtualKey: 8, keyDown: false)
        down?.flags = .maskCommand; up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap); up?.post(tap: .cghidEventTap)
        var waited = 0
        func poll() {
            if pb.changeCount != before || waited >= 12 {
                var result: Selection = .none
                if pb.changeCount != before {
                    if let s = pb.string(forType: .string), !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { result = .text(s) }
                    else if let d = imageData(from: pb) { result = .image(d) }
                    pb.clearContents()
                    if !saved.isEmpty { pb.writeObjects(saved) }
                } else if let s = pb.string(forType: .string), !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // Nothing was copied (e.g. a TUI like Claude Code owns the selection and already copied it on mouse-up):
                    // fall back to the clipboard. The panel shows the text, so a stale clipboard is visible, not silent.
                    Log.info("no copy happened; falling back to clipboard text")
                    result = .text(s)
                }
                Log.info("selection via ⌘C fallback: \(pb.changeCount != before ? "got data" : "nothing copied")")
                completion(result)
            } else {
                waited += 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: poll)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: poll)
    }

    static func imageData(from pb: NSPasteboard) -> Data? {
        if let d = pb.data(forType: .png) { return d }
        if let d = pb.data(forType: .tiff), let rep = NSBitmapImageRep(data: d), let png = rep.representation(using: .png, properties: [:]) { return png }
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], let u = urls.first,
           ["png", "jpg", "jpeg", "gif", "webp", "tiff", "heic"].contains(u.pathExtension.lowercased()),
           let img = NSImage(contentsOf: u), let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) { return png }
        return nil
    }
}
