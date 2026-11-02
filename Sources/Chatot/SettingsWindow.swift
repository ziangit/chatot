import AppKit
import SwiftUI
import ChatotCore

struct SettingsView: View {
    @AppStorage(AppConfig.Keys.targetLanguage) var targetLanguage = "Simplified Chinese"
    @AppStorage(AppConfig.Keys.claudeModel) var claudeModel = "claude-haiku-5-5"
    @AppStorage(ScreenshotWatcher.defaultsKey) var screenshotButton = true
    @State var apiKey = Keychain.read("ANTHROPIC_API_KEY") ?? ""
    @State var saved = ""

    var body: some View {
        Form {
            Section("Translation") {
                TextField("Target language", text: $targetLanguage)
                TextField("Claude model", text: $claudeModel)
                Text("Text already in the target language is translated to English.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Anthropic API key") {
                SecureField("sk-ant-…", text: $apiKey)
                HStack {
                    Button("Save to Keychain") { saved = Keychain.write("ANTHROPIC_API_KEY", apiKey) ? "Saved" : "Keychain error" }
                    Text(saved).font(.caption).foregroundStyle(.secondary)
                }
                Text("A key in .env (repo or ~/.config/chatot/.env) takes precedence over the keychain.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Screenshots") {
                Toggle("Offer to translate new screenshots", isOn: $screenshotButton)
            }
            Section("Where to find it") {
                Text("Right-click selected text or an image → Services → Translate with Chatot\nVS Code / Cursor terminal and editor: right-click → Translate with Chatot\nChrome: right-click → Translate with Chatot").font(.caption)
                Text("Glossary: ~/.config/chatot/glossary.txt (term = translation per line)").font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 460)
    }
}

final class SettingsWindowController: NSWindowController {
    convenience init() {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 460), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        w.title = "Chatot Settings"
        w.contentView = NSHostingView(rootView: SettingsView())
        w.center()
        w.isReleasedWhenClosed = false
        self.init(window: w)
    }
}
