import Foundation

/// OpenAI Codex CLI with ChatGPT sign-in. Non-streaming: the final message is read from the `-o` file.
public final class CodexCLIProvider: Provider {
    public let id = "codex-cli"
    public let supportsImages = true
    let model: String
    lazy var exe: String? = Shell.which("codex")

    public init(model: String) { self.model = model }
    public func isAvailable() -> Bool { exe != nil }

    public func stream(_ req: TranslationRequest) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard let exe = exe else { throw ChatotError.provider("codex not installed") }
                    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("chatot-codex-\(UUID().uuidString)")
                    try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
                    defer { try? FileManager.default.removeItem(at: tmp) }
                    let outFile = tmp.appendingPathComponent("out.txt")
                    var args = ["exec", "--skip-git-repo-check", "-s", "read-only", "-m", model, "-c", "model_reasoning_effort=low", "-C", tmp.path, "-o", outFile.path]
                    if let img = req.image {
                        let imgFile = tmp.appendingPathComponent("image.png")
                        try img.write(to: imgFile)
                        args += ["-i", imgFile.path]
                    }
                    args.append("-")
                    let prompt = req.system + "\n\n" + req.text
                    let (status, err) = try await Shell.run(exe, args, stdin: prompt) { _ in }
                    guard let text = try? String(contentsOf: outFile, encoding: .utf8), !text.isEmpty else {
                        throw ChatotError.provider("codex exited \(status) with no output: \(err.suffix(300))")
                    }
                    continuation.yield(text.trimmingCharacters(in: .whitespacesAndNewlines))
                    continuation.finish()
                } catch { continuation.finish(throwing: error) }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
