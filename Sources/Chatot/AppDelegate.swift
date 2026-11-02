import AppKit
import ChatotCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    let panel = TranslationPanelController()
    let services = ServicesHandler()
    let screenshotWatcher = ScreenshotWatcher()
    var settingsWindow: SettingsWindowController?
    var pauseItem: NSMenuItem?

    static var paused: Bool {
        get { UserDefaults.standard.bool(forKey: "paused") }
        set { UserDefaults.standard.set(newValue, forKey: "paused") }
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(handleURLEvent(_:reply:)), forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
    }

    /// chatot://translate?text=…  (VS Code and Chrome extensions)   chatot://image?url=…  (Chrome, right-click on an image)
    @objc func handleURLEvent(_ event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        guard let str = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue, let url = URL(string: str) else { return }
        Log.info("url event: \(url.scheme ?? "")://\(url.host ?? "") (\(str.count) chars)")
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        switch url.host {
        case "translate":
            if let t = items.first(where: { $0.name == "text" })?.value, !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Log.info("translate request: \(t.count) chars, starts \"\(t.prefix(40).replacingOccurrences(of: "\n", with: " "))\"")
                panel.translate(text: t)
            } else { panel.showMessage("chatot://translate needs a text parameter.") }
        case "image":
            guard let u = items.first(where: { $0.name == "url" })?.value, let imgURL = URL(string: u) else { panel.showMessage("chatot://image needs a url parameter."); return }
            panel.showMessage("Fetching image…")
            URLSession.shared.dataTask(with: imgURL) { [weak self] data, _, err in
                DispatchQueue.main.async {
                    guard let d = data, NSImage(data: d) != nil else {
                        Log.error("image url failed: \(err?.localizedDescription ?? "not an image") (\(data?.count ?? 0) bytes)")
                        self?.panel.showMessage("Could not load image: \(err?.localizedDescription ?? "not an image")"); return
                    }
                    Log.info("image url fetched (\(d.count / 1024) KB)")
                    self?.panel.translate(image: ImageUtil.downscale(d, maxSide: 1600) ?? d)
                }
            }.resume()
        default: panel.showMessage("Unknown chatot:// action: \(url.host ?? "")")
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.info("Chatot launched, bundle \(Bundle.main.bundleIdentifier ?? "none"), path \(Bundle.main.bundlePath)")
        installEditMenu()
        services.panel = panel
        NSApp.servicesProvider = services
        NSUpdateDynamicServices()
        setupStatusItem()
        screenshotWatcher.onTranslate = { [weak self] data in self?.panel.translate(image: data) }
        screenshotWatcher.start()
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
        }
        let menu = NSMenu()
        pauseItem = menu.addItem(withTitle: "Pause Chatot", action: #selector(togglePause), keyEquivalent: "")
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Chatot", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        for item in menu.items where item.action != #selector(NSApplication.terminate(_:)) { item.target = self }
        statusItem.menu = menu
        applyPauseState()
    }

    /// Pause = the screenshot card stays quiet. Right-click requests still work; Quit turns everything off.
    @objc func togglePause() { Self.paused.toggle(); applyPauseState() }

    private func applyPauseState() {
        let paused = Self.paused
        pauseItem?.title = paused ? "Resume Chatot" : "Pause Chatot"
        statusItem.button?.appearsDisabled = paused
        if paused { screenshotWatcher.hide() }
        Log.info("paused: \(paused)")
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

    @objc func openSettings() {
        if settingsWindow == nil { settingsWindow = SettingsWindowController() }
        settingsWindow?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
