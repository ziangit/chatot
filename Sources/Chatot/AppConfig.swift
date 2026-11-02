import Foundation
import ChatotCore

/// Config = `.env` discovery + Settings window overrides (UserDefaults) + keychain API keys.
enum AppConfig {
    enum Keys {
        static let targetLanguage = "targetLanguage", provider = "provider", claudeModel = "claudeModel", openaiModel = "openaiModel", deepseekModel = "deepseekModel", chunkChars = "chunkChars", showOriginal = "showOriginal"
    }
    static func current() -> Config {
        var c = Config.load()
        let d = UserDefaults.standard
        if let v = d.string(forKey: Keys.targetLanguage), !v.isEmpty { c.targetLanguage = v }
        if let v = d.string(forKey: Keys.provider), !v.isEmpty { c.provider = v }
        if let v = d.string(forKey: Keys.claudeModel), !v.isEmpty { c.claudeModel = v }
        if let v = d.string(forKey: Keys.openaiModel), !v.isEmpty { c.openaiModel = v }
        if let v = d.string(forKey: Keys.deepseekModel), !v.isEmpty { c.deepseekModel = v }
        let n = d.integer(forKey: Keys.chunkChars); if n > 100 { c.chunkTargetChars = n }
        if c.anthropicKey == nil, let k = Keychain.read("ANTHROPIC_API_KEY"), !k.isEmpty { c.anthropicKey = k }
        if c.openaiKey == nil, let k = Keychain.read("OPENAI_API_KEY"), !k.isEmpty { c.openaiKey = k }
        if c.deepseekKey == nil, let k = Keychain.read("DEEPSEEK_API_KEY"), !k.isEmpty { c.deepseekKey = k }
        return c
    }
}
