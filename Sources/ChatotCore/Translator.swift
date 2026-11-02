import Foundation

/// Events emitted while a translation runs. Segment indexes refer to the `segments` event's array.
public enum TranslationEvent {
    case segments([Segment])
    case delta(segment: Int, text: String)
    case completed(segment: Int, text: String, provider: String, seconds: Double)
    case retrying(segment: Int, provider: String, reason: String)
    case failed(segment: Int, error: String)
    case finished(seconds: Double)
}

/// Orchestrates chunking, parallel provider calls, validation, retry, and fallback.
public final class Translator {
    public let config: Config
    public let prompts: Prompts
    public let providers: [Provider]
    public var glossary: [String: String]

    public init(config: Config, prompts: Prompts, providers: [Provider], glossary: [String: String] = [:]) {
        self.config = config; self.prompts = prompts; self.providers = providers; self.glossary = glossary
    }

    /// Display names for the provider ids.
    public static let providerNames: [String: String] = ["claude": "Claude", "chatgpt": "ChatGPT", "deepseek": "DeepSeek"]

    /// The provider chosen in config (Claude by default). Empty when its key is missing.
    public static func makeProviders(config: Config) -> [Provider] {
        let p: Provider
        switch config.provider {
        case "chatgpt": p = OpenAICompatibleProvider(id: "chatgpt", apiKey: config.openaiKey, model: config.openaiModel, baseURL: "https://api.openai.com/v1", supportsImages: true)
        case "deepseek": p = OpenAICompatibleProvider(id: "deepseek", apiKey: config.deepseekKey, model: config.deepseekModel, baseURL: "https://api.deepseek.com", supportsImages: false)
        default: p = ClaudeAPIProvider(apiKey: config.anthropicKey, model: config.claudeModel, effort: config.claudeEffort)
        }
        if !p.isAvailable() { Log.info("\(p.id) unavailable: no API key"); return [] }
        return [p]
    }

    var expectCJK: Bool {
        let l = config.targetLanguage.lowercased()
        return l.contains("chinese") || l.contains("中文") || l.contains("japanese") || l.hasPrefix("zh") || l.hasPrefix("ja")
    }

    var systemPrompt: String { Prompts.decorate(prompts.translate, targetLanguage: config.targetLanguage, glossary: glossary) }

    /// Target for this text: the configured language, or English when the text is already in a CJK language.
    public func effectiveTarget(for text: String) -> String {
        expectCJK && Validator.isMostlyCJK(text) ? "English" : config.targetLanguage
    }

    /// Translate text. `chunk: false` sends the whole text as one segment.
    public func translate(_ text: String, chunk: Bool = true, onEvent: @escaping (TranslationEvent) -> Void) async {
        let start = Date()
        let segments = chunk ? Chunker.split(text, targetChars: config.chunkTargetChars) : [Segment(id: 0, kind: .translate, text: text)]
        onEvent(.segments(segments))
        let target = effectiveTarget(for: text)
        if target != config.targetLanguage { Log.info("source is mostly CJK; translating to \(target)") }
        let system = Prompts.decorate(prompts.translate, targetLanguage: target, glossary: glossary)
        let wantCJK = expectCJK && target == config.targetLanguage
        let limit = max(1, config.maxConcurrency)
        await withTaskGroup(of: Void.self) { group in
            var running = 0
            var iterator = segments.makeIterator()
            func launch(_ seg: Segment) {
                group.addTask { [self] in
                    if seg.kind == .passthrough {
                        onEvent(.completed(segment: seg.id, text: seg.text, provider: "passthrough", seconds: 0))
                        return
                    }
                    await translateSegment(seg, request: TranslationRequest(system: system, text: Prompts.wrapSource(seg.text)), expectCJK: wantCJK, onEvent: onEvent)
                }
            }
            while running < limit, let seg = iterator.next() { launch(seg); running += 1 }
            while running > 0 {
                await group.next()
                running -= 1
                if let seg = iterator.next() { launch(seg); running += 1 }
            }
        }
        onEvent(.finished(seconds: Date().timeIntervalSince(start)))
    }

    /// Translate an image (screenshot). One segment; no chunking.
    public func translateImage(_ image: Data, mediaType: String = "image/png", onEvent: @escaping (TranslationEvent) -> Void) async {
        let start = Date()
        let seg = Segment(id: 0, kind: .translate, text: "")
        onEvent(.segments([seg]))
        let system = Prompts.decorate(prompts.screenshot, targetLanguage: config.targetLanguage, glossary: glossary)
        let req = TranslationRequest(system: system, text: "Transcribe and translate this screenshot.", image: image, imageMediaType: mediaType)
        await translateSegment(seg, request: req, validate: false, onEvent: onEvent)
        onEvent(.finished(seconds: Date().timeIntervalSince(start)))
    }

    func translateSegment(_ seg: Segment, request: TranslationRequest, validate: Bool = true, expectCJK: Bool? = nil, onEvent: @escaping (TranslationEvent) -> Void) async {
        var errors: [String] = []
        let wantCJK = expectCJK ?? self.expectCJK
        let usable = providers.filter { request.image == nil || $0.supportsImages }
        for provider in usable {
            for attempt in 0..<2 {
                let t0 = Date()
                var acc = ""
                var streamed = ""
                var req = request
                if attempt > 0, let last = errors.last, last.contains("echo") {
                    // The model repeated the source; say so explicitly on the retry.
                    req = TranslationRequest(system: request.system, text: request.text + "\n\n(The previous answer repeated the source text unchanged. Output only the translation.)", image: request.image, imageMediaType: request.imageMediaType)
                }
                do {
                    for try await piece in provider.stream(req) {
                        acc += piece
                        // Only stream deltas live on the first attempt of the first provider; retries replace the text at the end.
                        if attempt == 0 && provider.id == usable.first?.id {
                            streamed += piece
                            onEvent(.delta(segment: seg.id, text: piece))
                        }
                    }
                    let out = acc.trimmingCharacters(in: .whitespacesAndNewlines)
                    if validate {
                        let v = Validator.validate(source: seg.text, output: out, expectCJK: wantCJK)
                        if !v.ok {
                            let reason = v.reason ?? "invalid"
                            Log.info("segment \(seg.id) \(provider.id) attempt \(attempt) rejected: \(reason)")
                            onEvent(.retrying(segment: seg.id, provider: provider.id, reason: reason))
                            errors.append("\(provider.id): \(reason)")
                            continue
                        }
                    } else if out.isEmpty {
                        errors.append("\(provider.id): empty"); continue
                    }
                    let secs = Date().timeIntervalSince(t0)
                    Log.info("segment \(seg.id) done via \(provider.id) in \(String(format: "%.2f", secs))s")
                    onEvent(.completed(segment: seg.id, text: out, provider: provider.id, seconds: secs))
                    return
                } catch {
                    let msg = "\(provider.id): \(error.localizedDescription)"
                    Log.error("segment \(seg.id) \(msg)")
                    errors.append(msg)
                    onEvent(.retrying(segment: seg.id, provider: provider.id, reason: error.localizedDescription))
                    if case ChatotError.http(let code, _) = error, code == 400 || code == 401 || code == 403 { break } // don't retry hard errors
                }
            }
        }
        onEvent(.failed(segment: seg.id, error: errors.isEmpty ? "no providers available" : errors.joined(separator: " | ")))
    }
}
