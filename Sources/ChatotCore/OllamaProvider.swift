import Foundation

/// Local Ollama server; optional offline tier.
public final class OllamaProvider: Provider {
    public let id = "ollama"
    public let supportsImages = false
    let model: String
    let baseURL: URL

    public init(model: String, baseURL: String) { self.model = model; self.baseURL = URL(string: baseURL)! }

    public func isAvailable() -> Bool {
        var ok = false
        let sem = DispatchSemaphore(value: 0)
        var r = URLRequest(url: baseURL.appendingPathComponent("api/version")); r.timeoutInterval = 0.5
        URLSession.shared.dataTask(with: r) { _, resp, _ in ok = (resp as? HTTPURLResponse)?.statusCode == 200; sem.signal() }.resume()
        _ = sem.wait(timeout: .now() + 0.7)
        return ok
    }

    public func stream(_ req: TranslationRequest) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let body: [String: Any] = ["model": model, "stream": true, "think": false, "options": ["temperature": 0.2, "num_ctx": 8192],
                                               "messages": [["role": "system", "content": req.system], ["role": "user", "content": req.text]]]
                    var r = URLRequest(url: baseURL.appendingPathComponent("api/chat"))
                    r.httpMethod = "POST"; r.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    r.httpBody = try JSONSerialization.data(withJSONObject: body)
                    let (bytes, resp) = try await URLSession.shared.bytes(for: r)
                    guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw ChatotError.provider("ollama HTTP error") }
                    for try await line in bytes.lines {
                        guard let d = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any] else { continue }
                        if let m = d["message"] as? [String: Any], let c = m["content"] as? String, !c.isEmpty { continuation.yield(c) }
                        if d["done"] as? Bool == true { break }
                    }
                    continuation.finish()
                } catch { continuation.finish(throwing: error) }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
