import AppKit
import ChatotCore

/// PopClip-style: after a drag-select or double-click in any app, shows a small floating "译" button next to the cursor.
/// Detection uses global mouse monitors (no permission) plus Accessibility to read the selection (permission needed).
final class SelectionWatcher {
    static let defaultsKey = "selectionButton"
    var onTranslate: ((String) -> Void)?
    private var monitors: [Any] = []
    private var downPoint = NSPoint.zero
    private var lastText = ""
    private var hideTimer: Timer?
    private let panel: NSPanel
    private let button: NSButton

    init() {
        button = NSButton(title: "译 Translate", target: nil, action: nil)
        button.bezelStyle = .rounded
        button.controlSize = .small
        button.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        button.sizeToFit()
        panel = NSPanel(contentRect: NSRect(origin: .zero, size: NSSize(width: button.frame.width + 8, height: button.frame.height + 8)), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.hasShadow = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isReleasedWhenClosed = false
        let content = NSView(frame: panel.contentRect(forFrameRect: panel.frame))
        button.frame.origin = NSPoint(x: 4, y: 4)
        content.addSubview(button)
        panel.contentView = content
        button.target = self
        button.action = #selector(clicked)
    }

    var enabled: Bool {
        if AppDelegate.paused { return false }
        return UserDefaults.standard.object(forKey: Self.defaultsKey) == nil ? true : UserDefaults.standard.bool(forKey: Self.defaultsKey)
    }

    func start() {
        guard monitors.isEmpty else { return }
        if let m = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown, handler: { [weak self] _ in
            self?.downPoint = NSEvent.mouseLocation; self?.hide()
        }) { monitors.append(m) }
        if let m = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp, handler: { [weak self] e in self?.mouseUp(e) }) { monitors.append(m) }
        Log.info("selection button watcher started")
    }

    private func mouseUp(_ e: NSEvent) {
        guard enabled else { return }
        let up = NSEvent.mouseLocation
        let dragged = hypot(up.x - downPoint.x, up.y - downPoint.y) > 4
        guard dragged || e.clickCount >= 2 else { return }
        if NSWorkspace.shared.frontmostApplication?.bundleIdentifier == Bundle.main.bundleIdentifier { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self = self else { return }
            guard let text = SelectionReader.axSelectedText()?.trimmingCharacters(in: .whitespacesAndNewlines), text.count >= 2 else { return }
            self.lastText = text
            self.show(at: up)
        }
    }

    private func show(at p: NSPoint) {
        var origin = NSPoint(x: p.x + 10, y: p.y + 10)
        if let vf = (NSScreen.screens.first { NSMouseInRect(p, $0.frame, false) } ?? NSScreen.main)?.visibleFrame {
            origin.x = min(max(vf.minX, origin.x), vf.maxX - panel.frame.width)
            origin.y = min(max(vf.minY, origin.y), vf.maxY - panel.frame.height)
        }
        panel.setFrameOrigin(origin)
        panel.orderFrontRegardless()
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 8, repeats: false) { [weak self] _ in self?.hide() }
    }

    func hide() {
        hideTimer?.invalidate(); hideTimer = nil
        if panel.isVisible { panel.orderOut(nil) }
    }

    @objc private func clicked() {
        let t = lastText
        hide()
        if !t.isEmpty { onTranslate?(t) }
    }
}
