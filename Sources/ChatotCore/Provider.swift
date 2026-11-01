import Foundation

public struct TranslationRequest {
    public var system: String
    public var text: String
    public var image: Data?
    public var imageMediaType: String?
    public init(system: String, text: String, image: Data? = nil, imageMediaType: String? = nil) {
        self.system = system; self.text = text; self.image = image; self.imageMediaType = imageMediaType
    }
}

/// A translation backend. Implementations stream text deltas; the translator assembles and validates them.
public protocol Provider: AnyObject {
    var id: String { get }
    var supportsImages: Bool { get }
    /// Cheap availability check (binary present, key present, server reachable).
    func isAvailable() -> Bool
    func stream(_ request: TranslationRequest) -> AsyncThrowingStream<String, Error>
}

/// Shared helper for providers that shell out to a CLI.
enum Shell {
    static func which(_ name: String) -> String? {
        let candidates = ["/opt/homebrew/bin", "/usr/local/bin", NSString(string: "~/.local/bin").expandingTildeInPath, "/usr/bin", "/bin"]
            .map { "\($0)/\(name)" }
        if let hit = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) { return hit }
        // nvm-style installs
        let nvm = NSString(string: "~/.nvm/versions/node").expandingTildeInPath
        if let versions = try? FileManager.default.contentsOfDirectory(atPath: nvm) {
            for v in versions.sorted().reversed() {
                let p = "\(nvm)/\(v)/bin/\(name)"
                if FileManager.default.isExecutableFile(atPath: p) { return p }
            }
        }
        // Fall back to PATH lookup through the login shell.
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/bin/zsh"); p.arguments = ["-lc", "command -v \(name)"]
        let out = Pipe(); p.standardOutput = out; p.standardError = FileHandle.nullDevice
        try? p.run(); p.waitUntilExit()
        let s = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return s.isEmpty ? nil : s
    }

    /// Runs a process, feeding stdin, streaming stdout lines to `onLine`. Returns exit status and stderr.
    static func run(_ exe: String, _ args: [String], stdin: String?, env: [String: String] = [:], onLine: @escaping (String) -> Void) async throws -> (Int32, String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: exe)
        p.arguments = args
        var e = ProcessInfo.processInfo.environment
        for (k, v) in env { e[k] = v }
        p.environment = e
        let inPipe = Pipe(), outPipe = Pipe(), errPipe = Pipe()
        p.standardInput = inPipe; p.standardOutput = outPipe; p.standardError = errPipe
        try p.run()
        if let stdin = stdin {
            inPipe.fileHandleForWriting.write(stdin.data(using: .utf8)!)
        }
        try? inPipe.fileHandleForWriting.close()
        let errTask = Task.detached { String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "" }
        for try await line in outPipe.fileHandleForReading.bytes.lines { onLine(line) }
        p.waitUntilExit()
        let err = await errTask.value
        return (p.terminationStatus, err)
    }
}
