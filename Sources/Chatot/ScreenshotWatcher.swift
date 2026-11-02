import AppKit
import ChatotCore

/// After a macOS screenshot (⇧⌘3/4/5, or "Copy Image" in the screenshot preview), shows a floating
/// "译 Translate screenshot" button at the bottom-right of the screen. Two sources, no permission needed:
/// a new image on the clipboard, or a new image file in the screenshot folder.
final class ScreenshotWatcher {
    static let defaultsKey = "screenshotButton"
    var onTranslate: ((Data) -> Void)?
    private let panel: NSPanel
    private let button: NSButton
    private var hideTimer: Timer?
    private var pending: Data?
    private var pollTimer: Timer?
    private var lastChangeCount = NSPasteboard.general.changeCount
    private var dirSource: DispatchSourceFileSystemObject?
    private var dirFD: Int32 = -1
    private var knownFiles: Set<String> = []
    private var folder: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")

    private let thumb = NSImageView()
    private let label = NSTextField(labelWithString: "Screenshot captured")

    init() {
        // A card: thumbnail on top, a big button below. Sits above the system screenshot UI (popUpMenu level).
        let w: CGFloat = 260, thumbH: CGFloat = 130, rowH: CGFloat = 44
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: w, height: thumbH + rowH + 22), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        panel.level = .popUpMenu   // after isFloatingPanel, which would reset it to .floating
        panel.hidesOnDeactivate = false
        panel.hasShadow = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isReleasedWhenClosed = false
        let content = NSVisualEffectView(frame: panel.contentRect(forFrameRect: panel.frame))
        content.material = .hudWindow; content.state = .active; content.wantsLayer = true
        content.layer?.cornerRadius = 12; content.layer?.masksToBounds = true
        thumb.frame = NSRect(x: 10, y: rowH + 12, width: w - 20, height: thumbH)
        thumb.imageScaling = .scaleProportionallyUpOrDown
        thumb.wantsLayer = true; thumb.layer?.cornerRadius = 6; thumb.layer?.masksToBounds = true
        label.frame = NSRect(x: 12, y: rowH + thumbH + 12 - 2, width: w - 24, height: 0)
        label.font = NSFont.systemFont(ofSize: 11); label.textColor = .secondaryLabelColor
        label.isHidden = true
        button = NSButton(title: "译  Translate this screenshot", target: nil, action: nil)
        button.bezelStyle = .rounded
        button.controlSize = .large
        button.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        button.keyEquivalent = "\r"
        button.frame = NSRect(x: 10, y: 8, width: w - 20, height: rowH - 8)
        content.addSubview(thumb); content.addSubview(button)
        panel.contentView = content
        button.target = self
        button.action = #selector(clicked)
    }

    var enabled: Bool {
        UserDefaults.standard.object(forKey: Self.defaultsKey) == nil ? true : UserDefaults.standard.bool(forKey: Self.defaultsKey)
    }

    func start() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in self?.pollClipboard() }
        // The first read of ~/Desktop triggers the "access your Desktop folder" permission dialog, and the open()
        // blocks until the user answers. Never do that on the main thread.
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let dir = Self.screenshotFolder()
            let files = Self.listing(of: dir)
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.folder = dir; self.knownFiles = files
                self.watchFolder()
                Log.info("screenshot watcher started (folder \(dir.path), \(files.count) files)")
            }
        }
    }

    /// `defaults read com.apple.screencapture location`, else ~/Desktop.
    static func screenshotFolder() -> URL {
        if let p = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location"), !p.isEmpty {
            let u = URL(fileURLWithPath: (p as NSString).expandingTildeInPath)
            if FileManager.default.fileExists(atPath: u.path) { return u }
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
    }

    static func listing(of dir: URL) -> Set<String> {
        Set((try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? [])
    }

    private func watchFolder() {
        dirFD = open(folder.path, O_EVTONLY)
        guard dirFD >= 0 else { Log.error("cannot watch \(folder.path)"); return }
        let src = DispatchSource.makeFileSystemObjectSource(fileDescriptor: dirFD, eventMask: .write, queue: .main)
        src.setEventHandler { [weak self] in self?.folderChanged() }
        src.setCancelHandler { [weak self] in if let fd = self?.dirFD, fd >= 0 { close(fd) } }
        src.resume()
        dirSource = src
    }

    private func folderChanged() {
        let dir = folder
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let now = Self.listing(of: dir)
            DispatchQueue.main.async { self?.folderChanged(now: now) }
        }
    }

    private func folderChanged(now: Set<String>) {
        let added = now.subtracting(knownFiles)
        knownFiles = now
        guard enabled else { return }
        let exts = ["png", "jpg", "jpeg", "heic", "tiff"]
        for name in added where !name.hasPrefix(".") && exts.contains((name as NSString).pathExtension.lowercased()) {
            let url = folder.appendingPathComponent(name)
            // Screenshots are written in one go, but give the writer a moment and skip anything not an image.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                guard let self = self, let data = FileManager.default.contents(atPath: url.path), NSImage(data: data) != nil else { return }
                Log.info("new screenshot file: \(name) (\(data.count / 1024) KB)")
                self.offer(data)
            }
            return
        }
    }

    private func pollClipboard() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount
        guard enabled, pb.string(forType: .string) == nil, let data = SelectionReader.imageData(from: pb) else { return }
        // Ignore images copied by Chatot itself and copies that came with a file (Finder copy).
        if pb.availableType(from: [.fileURL]) != nil { return }
        Log.info("new image on clipboard (\(data.count / 1024) KB)")
        offer(data)
    }

    private func offer(_ data: Data) {
        pending = data
        thumb.image = NSImage(data: data)
        // Next to the mouse (the user just clicked Done / Copy Image), clamped to the screen; never under the
        // system thumbnail in the bottom-right corner.
        let mouse = NSEvent.mouseLocation
        let vf = (NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main)?.visibleFrame ?? .zero
        var origin = NSPoint(x: mouse.x + 16, y: mouse.y - panel.frame.height - 16)
        origin.x = min(max(vf.minX + 8, origin.x), vf.maxX - panel.frame.width - 8)
        origin.y = min(max(vf.minY + 8, origin.y), vf.maxY - panel.frame.height - 8)
        panel.setFrameOrigin(origin)
        panel.orderFrontRegardless()
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: false) { [weak self] _ in self?.hide() }
        Log.info("screenshot card shown at \(Int(origin.x)),\(Int(origin.y))")
    }

    func hide() {
        hideTimer?.invalidate(); hideTimer = nil
        if panel.isVisible { panel.orderOut(nil) }
    }

    @objc private func clicked() {
        let d = pending
        hide()
        if let d = d { onTranslate?(d) }
    }
}

/// Drop target laid over the menubar icon: drag the screenshot thumbnail (or any image / image file) onto it.
final class ImageDropView: NSView {
    var onImage: ((Data) -> Void)?
    override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL, .png, .tiff])
    }
    required init?(coder: NSCoder) { fatalError() }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { .copy }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let data = SelectionReader.imageData(from: sender.draggingPasteboard) else { return false }
        Log.info("image dropped on menubar icon (\(data.count / 1024) KB)")
        onImage?(data)
        return true
    }
    // Let clicks reach the status button underneath.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
