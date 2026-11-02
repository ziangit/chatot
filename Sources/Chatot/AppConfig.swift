import Foundation
import ChatotCore

/// Config = `.env` discovery + Settings window overrides (UserDefaults) + keychain API keys.
enum AppConfig {
    enum Keys {
        static let targetLanguage = "targetLanguage", provider = "provider", claudeModel = "claudeModel", openaiModel = "openaiModel", deepseekModel = "deepseekModel", chunkChars = "chunkChars", showOriginal = "showOriginal"
    }
    /// The dropdown choices. Stored values outside these lists (e.g. left over from the old text fields) are ignored.
    static let languages = ["Simplified Chinese", "Traditional Chinese", "English", "Japanese", "Korean", "French", "German", "Spanish"]
    static let models: [String: [String]] = [
        "claude": ["claude-haiku-5-5", "claude-sonnet-5-5", "claude-opus-5-5"],
        "chatgpt": ["gpt-6-luna", "gpt-6.1-terra", "gpt-6.1-sol", "gpt-6-astra"],
        "deepseek": ["deepseek-flash", "deepseek-v4-pro"],
    ]
    static func current() -> Config {
        var c = Config.load()
        let d = UserDefaults.standard
        if let v = d.string(forKey: Keys.targetLanguage), languages.contains(v) { c.targetLanguage = v }
        if let v = d.string(forKey: Keys.provider), models[v] != nil { c.provider = v }
        if let v = d.string(forKey: Keys.claudeModel), models["claude"]!.contains(v) { c.claudeModel = v }
        if let v = d.string(forKey: Keys.openaiModel), models["chatgpt"]!.contains(v) { c.openaiModel = v }
        if let v = d.string(forKey: Keys.deepseekModel), models["deepseek"]!.contains(v) { c.deepseekModel = v }
        let n = d.integer(forKey: Keys.chunkChars); if n > 100 { c.chunkTargetChars = n }
        if c.anthropicKey == nil, let k = Keychain.read("ANTHROPIC_API_KEY"), !k.isEmpty { c.anthropicKey = k }
        if c.openaiKey == nil, let k = Keychain.read("OPENAI_API_KEY"), !k.isEmpty { c.openaiKey = k }
        if c.deepseekKey == nil, let k = Keychain.read("DEEPSEEK_API_KEY"), !k.isEmpty { c.deepseekKey = k }
        return c
    }
}
