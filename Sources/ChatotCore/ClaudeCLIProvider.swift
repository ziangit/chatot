import Foundation

/// Claude Code CLI in headless mode on the user's subscription. Fallback only: thinking cannot be disabled here.
public final class ClaudeCLIProvider: Provider {
    public let id = "claude-cli"
    public let supportsImages = true
    let model: String
    lazy var exe: String? = Shell.which("claude")

    public init(model: String = "haiku") { self.model = model }
    public func isAvailable() -> Bool { exe != nil }

    public func stream(_ req: TranslationRequest) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard let exe = exe else { throw ChatotError.provider("claude not installed") }
                    var args = ["-p", "--model", model, "--tools", "", "--output-format", "stream-json", "--include-partial-messages", "--verbose", "--no-session-persistence", "--system-prompt", req.system]
                    let stdin: String
                    if let img = req.image {
                        args += ["--input-format", "stream-json"]
                        let msg: [String: Any] = ["type": "user", "message": ["role": "user", "content": [
                            ["type": "text", "text": req.text],
                            ["type": "image", "source": ["type": "base64", "media_type": req.imageMediaType ?? "image/png", "data": img.base64EncodedString()]],
                        ]]]
                        stdin = String(data: try JSONSerialization.data(withJSONObject: msg), encoding: .utf8)! + "\n"
                    } else {
                        stdin = req.text
                    }
                    var sawText = false
                    let (status, err) = try await Shell.run(exe, args, stdin: stdin, env: ["CLAUDE_CODE_ENTRYPOINT": "chatot"]) { line in
                        guard let d = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any] else { return }
                        if d["type"] as? String == "stream_event", let ev = d["event"] as? [String: Any], ev["type"] as? String == "content_block_delta",
                           let delta = ev["delta"] as? [String: Any], delta["type"] as? String == "text_delta", let t = delta["text"] as? String {
                            sawText = true
                            continuation.yield(t)
                        }
                    }
                    if !sawText { throw ChatotError.provider("claude exited \(status) with no text: \(err.suffix(300))") }
                    continuation.finish()
                } catch { continuation.finish(throwing: error) }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
