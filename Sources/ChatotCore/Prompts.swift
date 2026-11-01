import Foundation

/// Loads the prompt templates shipped as package resources.
public struct Prompts {
    public let translate: String
    public let screenshot: String

    public init(translate: String, screenshot: String) { self.translate = translate; self.screenshot = screenshot }

    public static func load() throws -> Prompts {
        Prompts(translate: try read("translate"), screenshot: try read("screenshot"))
    }

    private static func read(_ name: String) throws -> String {
        guard let url = Bundle.module.url(forResource: name, withExtension: "md", subdirectory: "Prompts") else {
            throw ChatotError.missingResource("Prompts/\(name).md")
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    /// Wraps source text so the model translates only the content, not harness noise.
    public static func wrapSource(_ text: String) -> String { "<source>\n\(text)\n</source>" }

    /// Appends a glossary and target language to a system prompt.
    public static func decorate(_ system: String, targetLanguage: String, glossary: [String: String]) -> String {
        var s = system
        if targetLanguage != "Simplified Chinese" {
            s += "\n\nTarget language override: translate into \(targetLanguage) instead of Chinese; apply the typography rules in spirit for that language."
        }
        if !glossary.isEmpty {
            let lines = glossary.sorted { $0.key < $1.key }.map { "\($0.key) → \($0.value)" }
            s += "\n\nGlossary (use these renderings consistently):\n" + lines.joined(separator: "\n")
        }
        return s
    }
}

public enum ChatotError: Error, LocalizedError {
    case missingResource(String)
    case missingAPIKey
    case http(Int, String)
    case provider(String)
    case validation(String)
    case allProvidersFailed([String])

    public var errorDescription: String? {
        switch self {
        case .missingResource(let r): return "Missing resource: \(r)"
        case .missingAPIKey: return "ANTHROPIC_API_KEY is not set (put it in .env or ~/.config/chatot/.env)"
        case .http(let code, let body): return "HTTP \(code): \(body)"
        case .provider(let m): return m
        case .validation(let m): return "Validation failed: \(m)"
        case .allProvidersFailed(let errs): return "All providers failed: " + errs.joined(separator: " | ")
        }
    }
}
