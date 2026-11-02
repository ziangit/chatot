import Foundation

/// Runtime configuration. Secrets come from the environment or a `.env` file; never from source.
public struct Config: Equatable {
    public var anthropicKey: String?
    public var openaiKey: String?
    public var deepseekKey: String?
    /// "claude" | "chatgpt" | "deepseek"
    public var provider: String = "claude"
    public var claudeModel: String = "claude-haiku-5-5"
    public var openaiModel: String = "gpt-5-mini"
    public var deepseekModel: String = "deepseek-chat"
    public var targetLanguage: String = "Simplified Chinese"
    public var maxConcurrency: Int = 6
    public var chunkTargetChars: Int = 700
    public var claudeEffort: String = "low"
    public var logPath: String = NSString(string: "~/Library/Logs/chatot.log").expandingTildeInPath

    public init() {}

    /// Search order: process environment, `~/.config/chatot/.env`, then a `.env` found by walking up
    /// from the executable and from the working directory (so dev builds inside the repo find the repo's `.env`).
    public static func load(environment: [String: String] = ProcessInfo.processInfo.environment) -> Config {
        var merged: [String: String] = [:]
        for url in candidateEnvFiles() {
            if let text = try? String(contentsOf: url, encoding: .utf8) {
                for (k, v) in parseDotEnv(text) where merged[k] == nil { merged[k] = v }
            }
        }
        for (k, v) in environment { merged[k] = v } // real environment wins
        var c = Config()
        c.anthropicKey = merged["ANTHROPIC_API_KEY"].flatMap { $0.isEmpty ? nil : $0 }
        c.openaiKey = merged["OPENAI_API_KEY"].flatMap { $0.isEmpty ? nil : $0 }
        c.deepseekKey = merged["DEEPSEEK_API_KEY"].flatMap { $0.isEmpty ? nil : $0 }
        if let m = merged["CHATOT_PROVIDER"], !m.isEmpty { c.provider = m }
        if let m = merged["CHATOT_CLAUDE_MODEL"], !m.isEmpty { c.claudeModel = m }
        if let m = merged["CHATOT_OPENAI_MODEL"], !m.isEmpty { c.openaiModel = m }
        if let m = merged["CHATOT_DEEPSEEK_MODEL"], !m.isEmpty { c.deepseekModel = m }
        if let m = merged["CHATOT_TARGET_LANG"], !m.isEmpty { c.targetLanguage = m }
        if let m = merged["CHATOT_EFFORT"], !m.isEmpty { c.claudeEffort = m }
        if let m = merged["CHATOT_CONCURRENCY"], let n = Int(m), n > 0 { c.maxConcurrency = n }
        if let m = merged["CHATOT_CHUNK_CHARS"], let n = Int(m), n > 100 { c.chunkTargetChars = n }
        return c
    }

    static func candidateEnvFiles() -> [URL] {
        var urls: [URL] = []
        let home = FileManager.default.homeDirectoryForCurrentUser
        urls.append(home.appendingPathComponent(".config/chatot/.env"))
        var starts: [URL] = [URL(fileURLWithPath: FileManager.default.currentDirectoryPath)]
        starts.append(Bundle.main.executableURL?.deletingLastPathComponent() ?? URL(fileURLWithPath: "/"))
        for start in starts {
            var dir = start
            for _ in 0..<8 {
                urls.append(dir.appendingPathComponent(".env"))
                let parent = dir.deletingLastPathComponent()
                if parent.path == dir.path { break }
                dir = parent
            }
        }
        return urls
    }

    public static func parseDotEnv(_ text: String) -> [String: String] {
        var out: [String: String] = [:]
        for raw in text.split(separator: "\n", omittingEmptySubsequences: true) {
            var line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            if line.hasPrefix("export ") { line = String(line.dropFirst(7)) }
            guard let eq = line.firstIndex(of: "=") else { continue }
            let key = line[..<eq].trimmingCharacters(in: .whitespaces)
            var value = line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces)
            if value.count >= 2, let f = value.first, let l = value.last, (f == "\"" && l == "\"") || (f == "'" && l == "'") {
                value = String(value.dropFirst().dropLast())
            }
            out[key] = value
        }
        return out
    }
}
