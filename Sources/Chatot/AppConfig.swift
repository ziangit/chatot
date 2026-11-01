import Foundation
import ChatotCore

/// Config = `.env` discovery + Settings window overrides (UserDefaults) + keychain API key.
enum AppConfig {
    enum Keys {
        static let targetLanguage = "targetLanguage", providers = "providers", claudeModel = "claudeModel", codexModel = "codexModel", chunkChars = "chunkChars", showOriginal = "showOriginal"
    }
    static func current() -> Config {
        var c = Config.load()
        let d = UserDefaults.standard
        if let v = d.string(forKey: Keys.targetLanguage), !v.isEmpty { c.targetLanguage = v }
        if let v = d.string(forKey: Keys.providers), !v.isEmpty { c.providerOrder = v.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
        if let v = d.string(forKey: Keys.claudeModel), !v.isEmpty { c.claudeModel = v }
        if let v = d.string(forKey: Keys.codexModel), !v.isEmpty { c.codexModel = v }
        let n = d.integer(forKey: Keys.chunkChars); if n > 100 { c.chunkTargetChars = n }
        if c.anthropicKey == nil, let k = Keychain.read("ANTHROPIC_API_KEY"), !k.isEmpty { c.anthropicKey = k }
        return c
    }
}
