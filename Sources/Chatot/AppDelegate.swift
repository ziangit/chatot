import AppKit
import ChatotCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    let panel = TranslationPanelController()
    let services = ServicesHandler()
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
        case "region": translateRegion()
        case "clipboard": translateClipboard()
        case "selection": translateSelection()
        default: panel.showMessage("Unknown chatot:// action: \(url.host ?? "")")
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.info("Chatot launched, bundle \(Bundle.main.bundleIdentifier ?? "none"), path \(Bundle.main.bundlePath)")
        services.panel = panel
        NSApp.servicesProvider = services
        NSUpdateDynamicServices()
        setupStatusItem()
        registerHotKeys()
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
        menu.addItem(withTitle: "Translate Selection", action: #selector(translateSelection), keyEquivalent: "")
        menu.addItem(withTitle: "Translate Screen Region", action: #selector(translateRegion), keyEquivalent: "")
        menu.addItem(withTitle: "Translate Clipboard", action: #selector(translateClipboard), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Show Panel", action: #selector(showPanel), keyEquivalent: "")
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(withTitle: "Open Log", action: #selector(openLog), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Chatot", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        for item in menu.items where item.action != #selector(NSApplication.terminate(_:)) { item.target = self }
        statusItem.menu = menu
    }

    func registerHotKeys() {
        let hk = HotKeyCenter.shared
        hk.register(id: 1, keyCode: 17, modifiers: hk.optionCommand) { [weak self] in self?.translateSelection() } // ⌥⌘T
        hk.register(id: 2, keyCode: 15, modifiers: hk.optionCommand) { [weak self] in self?.translateRegion() }    // ⌥⌘R
        Log.info("hotkeys registered: ⌥⌘T selection, ⌥⌘R region")
    }

    @objc func translateSelection() {
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

    @objc func showPanel() { panel.show() }
    @objc func openLog() { NSWorkspace.shared.open(URL(fileURLWithPath: Log.path)) }
    @objc func openSettings() {
        if settingsWindow == nil { settingsWindow = SettingsWindowController() }
        settingsWindow?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
