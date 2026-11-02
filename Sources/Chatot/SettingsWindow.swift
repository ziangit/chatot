import AppKit
import SwiftUI
import ChatotCore

struct SettingsView: View {
    @AppStorage(L10n.key) var language = "system"
    @AppStorage(AppConfig.Keys.targetLanguage) var targetLanguage = "Simplified Chinese"
    @AppStorage(AppConfig.Keys.provider) var provider = "claude"
    @AppStorage(AppConfig.Keys.claudeModel) var claudeModel = "claude-haiku-5-5"
    @AppStorage(AppConfig.Keys.openaiModel) var openaiModel = "gpt-5-mini"
    @AppStorage(AppConfig.Keys.deepseekModel) var deepseekModel = "deepseek-chat"
    @AppStorage(ScreenshotWatcher.defaultsKey) var screenshotButton = true
    @State var apiKey = ""
    @State var saved = ""
    var onLanguageChange: () -> Void

    var keyAccount: String { provider == "chatgpt" ? "OPENAI_API_KEY" : provider == "deepseek" ? "DEEPSEEK_API_KEY" : "ANTHROPIC_API_KEY" }
    var modelBinding: Binding<String> { provider == "chatgpt" ? $openaiModel : provider == "deepseek" ? $deepseekModel : $claudeModel }

    var body: some View {
        Form {
            Section(L("General")) {
                Picker(L("Language"), selection: $language) {
                    Text(L("System")).tag("system"); Text("English").tag("en"); Text("中文").tag("zh-Hans")
                }
                .onChange(of: language) { _, _ in onLanguageChange() }
                TextField(L("Target language"), text: $targetLanguage)
                Text(L("target_hint")).font(.caption).foregroundStyle(.secondary)
            }
            Section(L("Provider")) {
                Picker(L("Provider"), selection: $provider) {
                    Text("Claude").tag("claude"); Text("ChatGPT").tag("chatgpt"); Text("DeepSeek").tag("deepseek")
                }
                .onChange(of: provider) { _, _ in apiKey = Keychain.read(keyAccount) ?? ""; saved = "" }
                TextField(L("Model"), text: modelBinding)
                SecureField(L("API key"), text: $apiKey)
                HStack {
                    Button(L("Save to Keychain")) { saved = Keychain.write(keyAccount, apiKey) ? L("Saved") : L("Keychain error") }
                    Text(saved).font(.caption).foregroundStyle(.secondary)
                }
                Text(L("key_hint")).font(.caption).foregroundStyle(.secondary)
                if provider == "deepseek" { Text(L("deepseek_hint")).font(.caption).foregroundStyle(.orange) }
            }
            Section(L("Screenshots")) {
                Toggle(L("Offer to translate new screenshots"), isOn: $screenshotButton)
            }
            Section(L("Where to find it")) {
                Text(L("where_text")).font(.caption)
                Text(L("glossary_hint")).font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 560)
        .onAppear { apiKey = Keychain.read(keyAccount) ?? "" }
    }
}

final class SettingsWindowController: NSWindowController {
    var onLanguageChange: (() -> Void)?
    convenience init(onLanguageChange: @escaping () -> Void) {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 560), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        w.title = L("Chatot Settings")
        w.isReleasedWhenClosed = false
        self.init(window: w)
        self.onLanguageChange = onLanguageChange
        w.contentView = NSHostingView(rootView: SettingsView(onLanguageChange: { [weak self] in self?.reload() }))
        w.center()
    }
    /// Rebuild the view so every label picks up the new language.
    func reload() {
        window?.title = L("Chatot Settings")
        window?.contentView = NSHostingView(rootView: SettingsView(onLanguageChange: { [weak self] in self?.reload() }))
        onLanguageChange?()
    }
}
