import Foundation

/// OpenAI-style `chat/completions` streaming, used for ChatGPT (api.openai.com) and DeepSeek (api.deepseek.com).
public final class OpenAICompatibleProvider: Provider {
    public let id: String
    public let supportsImages: Bool
    let apiKey: String?
    public let model: String
    let baseURL: String
    let session: URLSession

    public init(id: String, apiKey: String?, model: String, baseURL: String, supportsImages: Bool) {
        self.id = id; self.apiKey = apiKey; self.model = model; self.baseURL = baseURL; self.supportsImages = supportsImages
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
                    var userContent: Any = req.text
                    if let img = req.image {
                        userContent = [
                            ["type": "text", "text": req.text],
                            ["type": "image_url", "image_url": ["url": "data:\(req.imageMediaType ?? "image/png");base64,\(img.base64EncodedString())"]],
                        ]
                    }
                    let body: [String: Any] = [
                        "model": model,
                        "stream": true,
                        "messages": [["role": "system", "content": req.system], ["role": "user", "content": userContent]],
                    ]
                    var r = URLRequest(url: URL(string: baseURL + "/chat/completions")!)
                    r.httpMethod = "POST"
                    r.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    r.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
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
                        if json == "[DONE]" { break }
                        guard let d = try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any] else { continue }
                        if let e = d["error"] as? [String: Any] { throw ChatotError.provider("API error: \(e["message"] as? String ?? "\(e)")") }
                        if let choices = d["choices"] as? [[String: Any]], let delta = choices.first?["delta"] as? [String: Any], let t = delta["content"] as? String, !t.isEmpty {
                            continuation.yield(t)
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
