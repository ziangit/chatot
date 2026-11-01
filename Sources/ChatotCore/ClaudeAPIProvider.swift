import Foundation

/// Anthropic Messages API, streamed over SSE. Thinking disabled, effort low, system prompt cached.
public final class ClaudeAPIProvider: Provider {
    public let id = "claude-api"
    public let supportsImages = true
    let apiKey: String?
    let model: String
    let effort: String
    let session: URLSession

    public init(apiKey: String?, model: String, effort: String = "low") {
        self.apiKey = apiKey; self.model = model; self.effort = effort
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 120
        session = URLSession(configuration: cfg)
    }

    public func isAvailable() -> Bool { apiKey != nil }

    public func stream(_ req: TranslationRequest) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard let key = apiKey else { throw ChatotError.missingAPIKey }
                    var content: [[String: Any]] = [["type": "text", "text": req.text]]
                    if let img = req.image {
                        content.append(["type": "image", "source": ["type": "base64", "media_type": req.imageMediaType ?? "image/png", "data": img.base64EncodedString()]])
                    }
                    let body: [String: Any] = [
                        "model": model,
                        "max_tokens": 16000,
                        "stream": true,
                        "thinking": ["type": "disabled"],
                        "output_config": ["effort": effort],
                        "system": [["type": "text", "text": req.system, "cache_control": ["type": "ephemeral"]]],
                        "messages": [["role": "user", "content": content]],
                    ]
                    var r = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
                    r.httpMethod = "POST"
                    r.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    r.setValue(key, forHTTPHeaderField: "x-api-key")
                    r.setValue("2026-10-21", forHTTPHeaderField: "anthropic-version")
                    r.httpBody = try JSONSerialization.data(withJSONObject: body)
                    let (bytes, resp) = try await session.bytes(for: r)
                    guard let http = resp as? HTTPURLResponse else { throw ChatotError.provider("no HTTP response") }
                    if http.statusCode != 200 {
                        var buf = ""
                        for try await line in bytes.lines { buf += line; if buf.count > 2000 { break } }
                        throw ChatotError.http(http.statusCode, buf)
                    }
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data:") else { continue }
                        let json = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                        guard let d = try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any] else { continue }
                        let type = d["type"] as? String
                        if type == "content_block_delta", let delta = d["delta"] as? [String: Any], delta["type"] as? String == "text_delta", let t = delta["text"] as? String {
                            continuation.yield(t)
                        } else if type == "error", let e = d["error"] as? [String: Any] {
                            throw ChatotError.provider("API error: \(e["message"] as? String ?? "\(e)")")
                        } else if type == "message_delta", let delta = d["delta"] as? [String: Any], let stop = delta["stop_reason"] as? String, stop == "refusal" {
                            throw ChatotError.provider("model refused the request")
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
