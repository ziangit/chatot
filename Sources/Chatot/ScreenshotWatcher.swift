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

    init() {
        button = NSButton(title: "译 Translate screenshot", target: nil, action: nil)
        button.bezelStyle = .rounded
        button.controlSize = .regular
        button.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        button.sizeToFit()
        panel = NSPanel(contentRect: NSRect(origin: .zero, size: NSSize(width: button.frame.width + 12, height: button.frame.height + 12)), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.hasShadow = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isReleasedWhenClosed = false
        let content = NSView(frame: panel.contentRect(forFrameRect: panel.frame))
        button.frame.origin = NSPoint(x: 6, y: 6)
        content.addSubview(button)
        panel.contentView = content
        button.target = self
        button.action = #selector(clicked)
    }

    var enabled: Bool {
        UserDefaults.standard.object(forKey: Self.defaultsKey) == nil ? true : UserDefaults.standard.bool(forKey: Self.defaultsKey)
    }

    func start() {
        folder = Self.screenshotFolder()
        knownFiles = Self.listing(of: folder)
        watchFolder()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in self?.pollClipboard() }
        Log.info("screenshot watcher started (folder \(folder.path))")
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
        let now = Self.listing(of: folder)
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
        guard let vf = NSScreen.main?.visibleFrame else { return }
        // Bottom-right, where macOS shows the screenshot thumbnail.
        panel.setFrameOrigin(NSPoint(x: vf.maxX - panel.frame.width - 16, y: vf.minY + 16))
        panel.orderFrontRegardless()
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: false) { [weak self] _ in self?.hide() }
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
