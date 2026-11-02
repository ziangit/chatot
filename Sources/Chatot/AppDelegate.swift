import AppKit
import ApplicationServices
import ChatotCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    let panel = TranslationPanelController()
    let services = ServicesHandler()
    let selectionWatcher = SelectionWatcher()
    let screenshotWatcher = ScreenshotWatcher()
    var settingsWindow: SettingsWindowController?

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(handleURLEvent(_:reply:)), forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
    }

    /// chatot://translate?text=...  (used by the VS Code extension and any other integration)
    @objc func handleURLEvent(_ event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        guard let str = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue, let url = URL(string: str) else { return }
        Log.info("url event: \(url.scheme ?? "")://\(url.host ?? "") (\(str.count) chars)")
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        switch url.host {
        case "translate":
            if let t = items.first(where: { $0.name == "text" })?.value, !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { panel.translate(text: t) }
            else { panel.showMessage("chatot://translate needs a text parameter.") }
        case "image":
            // chatot://image?url=https://… (Chrome extension, right-click on an image): download, then translate.
            guard let u = items.first(where: { $0.name == "url" })?.value, let imgURL = URL(string: u) else { panel.showMessage("chatot://image needs a url parameter."); return }
            panel.showMessage("Fetching image…")
            URLSession.shared.dataTask(with: imgURL) { [weak self] data, _, err in
                DispatchQueue.main.async {
                    guard let d = data, NSImage(data: d) != nil else {
                        Log.error("image url failed: \(err?.localizedDescription ?? "not an image") (\(data?.count ?? 0) bytes)")
                        self?.panel.showMessage("Could not load image: \(err?.localizedDescription ?? "not an image")"); return
                    }
                    Log.info("image url fetched (\(d.count / 1024) KB)")
                    self?.panel.translate(image: RegionCapture.downscale(d, maxSide: 1600) ?? d)
                }
            }.resume()
        case "region": translateRegion()
        case "clipboard": translateClipboard()
        case "selection": translateSelection()
        default: panel.showMessage("Unknown chatot:// action: \(url.host ?? "")")
        }
    }

    static var paused: Bool {
        get { UserDefaults.standard.bool(forKey: "paused") }
        set { UserDefaults.standard.set(newValue, forKey: "paused") }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.info("Chatot launched, bundle \(Bundle.main.bundleIdentifier ?? "none"), path \(Bundle.main.bundlePath)")
        installEditMenu()
        services.panel = panel
        NSApp.servicesProvider = services
        NSUpdateDynamicServices()
        setupStatusItem()
        registerHotKeys()
        selectionWatcher.onTranslate = { [weak self] text in self?.panel.translate(text: text) }
        selectionWatcher.start()
        screenshotWatcher.onTranslate = { [weak self] data in self?.panel.translate(image: data) }
        screenshotWatcher.start()
        // Accessibility powers ⌥⌘T, the 译 button and panel placement. Ask once per install, never on every launch.
        let trusted = AXIsProcessTrusted()
        if !trusted && !UserDefaults.standard.bool(forKey: "axPrompted") {
            UserDefaults.standard.set(true, forKey: "axPrompted")
            _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
        }
        Log.info("accessibility trusted: \(trusted)")
        if let arg = CommandLine.arguments.dropFirst().first(where: { $0.hasPrefix("--translate=") }) {
            // Dev hook: `Chatot --translate="text"` opens the panel immediately.
            panel.translate(text: String(arg.dropFirst("--translate=".count)))
        }
        if let arg = CommandLine.arguments.dropFirst().first(where: { $0.hasPrefix("--snapshot=") }) {
            let path = String(arg.dropFirst("--snapshot=".count))
            DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in self?.panel.snapshot(to: path) }
        }
    }

    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let b = statusItem.button {
            b.image = NSImage(systemSymbolName: "character.bubble", accessibilityDescription: "Chatot")
            b.image?.isTemplate = true
            let drop = ImageDropView(frame: b.bounds)
            drop.autoresizingMask = [.width, .height]
            drop.onImage = { [weak self] data in self?.panel.translate(image: data) }
            b.addSubview(drop)
        }
        let menu = NSMenu()
        menu.addItem(withTitle: "Translate Selection", action: #selector(translateSelection), keyEquivalent: "")
        menu.addItem(withTitle: "Translate Screen Region", action: #selector(translateRegion), keyEquivalent: "")
        menu.addItem(withTitle: "Translate Clipboard", action: #selector(translateClipboard), keyEquivalent: "")
        menu.addItem(withTitle: "Translate Last Screenshot", action: #selector(translateLastScreenshot), keyEquivalent: "")
        menu.addItem(.separator())
        pauseItem = menu.addItem(withTitle: "Pause Chatot", action: #selector(togglePause), keyEquivalent: "")
        if !AXIsProcessTrusted() {
            menu.addItem(withTitle: "Grant Accessibility Access…", action: #selector(openAccessibilitySettings), keyEquivalent: "")
        }
        menu.addItem(withTitle: "Show Panel", action: #selector(showPanel), keyEquivalent: "")
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(withTitle: "Open Log", action: #selector(openLog), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Chatot", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        for item in menu.items where item.action != #selector(NSApplication.terminate(_:)) { item.target = self }
        statusItem.menu = menu
        applyPauseState()
    }

    var pauseItem: NSMenuItem?

    /// Pause = no automatic pop-ups (译 button, screenshot card) and hotkeys ignored. Explicit right-click / URL
    /// requests still work. Quit is in the same menu for turning it off entirely.
    @objc func togglePause() { Self.paused.toggle(); applyPauseState() }

    private func applyPauseState() {
        let paused = Self.paused
        pauseItem?.title = paused ? "Resume Chatot" : "Pause Chatot"
        statusItem.button?.appearsDisabled = paused
        if paused { selectionWatcher.hide(); screenshotWatcher.hide() }
        Log.info("paused: \(paused)")
    }

    @objc func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    /// Menuless accessory apps get no ⌘C/⌘A/⌘V; an Edit menu (never shown) wires the key equivalents.
    private func installEditMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem(); main.addItem(appItem)
        let appMenu = NSMenu(); appItem.submenu = appMenu
        appMenu.addItem(withTitle: "Quit Chatot", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let editItem = NSMenuItem(); main.addItem(editItem)
        let edit = NSMenu(title: "Edit"); editItem.submenu = edit
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        NSApp.mainMenu = main
    }

    func registerHotKeys() {
        let hk = HotKeyCenter.shared
        hk.register(id: 1, keyCode: 17, modifiers: hk.optionCommand) { [weak self] in self?.translateSelection() } // ⌥⌘T
        hk.register(id: 2, keyCode: 15, modifiers: hk.optionCommand) { [weak self] in self?.translateRegion() }    // ⌥⌘R
        Log.info("hotkeys registered: ⌥⌘T selection, ⌥⌘R region")
    }

    @objc func translateSelection() {
        if Self.paused { return }
        SelectionReader.readSelection { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .text(let s): self?.panel.translate(text: s)
                case .image(let d): self?.panel.translate(image: d)
                case .none: self?.panel.showMessage("No text selected. Select text, then press ⌥⌘T.")
                }
            }
        }
    }

    @objc func translateRegion() {
        if Self.paused { return }
        RegionCapture.capture { [weak self] data in
            DispatchQueue.main.async {
                if let d = data { self?.panel.translate(image: d) } else { Log.info("region capture cancelled") }
            }
        }
    }

    @objc func translateClipboard() {
        let pb = NSPasteboard.general
        if let s = pb.string(forType: .string), !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { panel.translate(text: s) }
        else if let d = SelectionReader.imageData(from: pb) { panel.translate(image: d) }
        else { panel.showMessage("Clipboard has no text or image.") }
    }

    @objc func translateLastScreenshot() {
        let dir = ScreenshotWatcher.screenshotFolder()
        let files = ((try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey])) ?? [])
            .filter { ["png", "jpg", "jpeg", "heic", "tiff"].contains($0.pathExtension.lowercased()) }
            .sorted { ((try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast) > ((try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast) }
        if let f = files.first, let d = FileManager.default.contents(atPath: f.path) { panel.translate(image: d) }
        else { panel.showMessage("No screenshot found in \(dir.path).") }
    }

    @objc func showPanel() { panel.show() }
    @objc func openLog() { NSWorkspace.shared.open(URL(fileURLWithPath: Log.path)) }
    @objc func openSettings() {
        if settingsWindow == nil { settingsWindow = SettingsWindowController() }
        settingsWindow?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
