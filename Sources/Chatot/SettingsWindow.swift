import AppKit
import SwiftUI
import ChatotCore

struct SettingsView: View {
    @AppStorage(AppConfig.Keys.targetLanguage) var targetLanguage = "Simplified Chinese"
    @AppStorage(AppConfig.Keys.providers) var providers = "claude-api"
    @AppStorage(AppConfig.Keys.claudeModel) var claudeModel = "claude-haiku-5-5"
    @AppStorage(AppConfig.Keys.codexModel) var codexModel = "gpt-6-luna"
    @AppStorage(AppConfig.Keys.chunkChars) var chunkChars = 700
    @AppStorage(SelectionWatcher.defaultsKey) var selectionButton = true
    @AppStorage(ScreenshotWatcher.defaultsKey) var screenshotButton = true
    @State var apiKey = Keychain.read("ANTHROPIC_API_KEY") ?? ""
    @State var saved = ""
    @State var available: [String] = []

    var body: some View {
        Form {
            Section("Translation") {
                TextField("Target language", text: $targetLanguage)
                TextField("Provider order (comma-separated)", text: $providers)
                Text("Available now: \(available.isEmpty ? "none" : available.joined(separator: ", "))").font(.caption).foregroundStyle(.secondary)
                TextField("Claude model", text: $claudeModel)
                TextField("Codex model", text: $codexModel)
                Stepper("Chunk size: \(chunkChars) chars", value: $chunkChars, in: 200...3000, step: 100)
            }
            Section("Anthropic API key") {
                SecureField("sk-ant-…", text: $apiKey)
                HStack {
                    Button("Save to Keychain") { saved = Keychain.write("ANTHROPIC_API_KEY", apiKey) ? "Saved" : "Keychain error"; refresh() }
                    Text(saved).font(.caption).foregroundStyle(.secondary)
                }
                Text("A key in .env (repo or ~/.config/chatot/.env) takes precedence over the keychain.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Triggers") {
                Toggle("Show a floating 译 button after selecting text in any app", isOn: $selectionButton)
                Toggle("Offer to translate new screenshots (file or clipboard)", isOn: $screenshotButton)
            }
            Section("Shortcuts") {
                Text("⌥⌘T  Translate selection\n⌥⌘R  Translate screen region\nRight-click → Services → Translate with Chatot").font(.system(.body, design: .monospaced))
                Text("Glossary: ~/.config/chatot/glossary.txt (term = translation per line)").font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 600)
        .onAppear(perform: refresh)
    }

    func refresh() { available = Translator.makeProviders(config: AppConfig.current()).map { $0.id } }
}

final class SettingsWindowController: NSWindowController {
    convenience init() {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 520), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        w.title = "Chatot Settings"
        w.contentView = NSHostingView(rootView: SettingsView())
        w.center()
        w.isReleasedWhenClosed = false
        self.init(window: w)
    }
}
