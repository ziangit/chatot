import Foundation

/// Minimal append-only logger shared by the app and CLI.
public enum Log {
    public static var path: String = NSString(string: "~/Library/Logs/chatot.log").expandingTildeInPath
    public static var echoToStderr = false
    private static let queue = DispatchQueue(label: "chatot.log")
    private static let fmt: ISO8601DateFormatter = { let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f }()

    public static func info(_ msg: String) { write("INFO", msg) }
    public static func error(_ msg: String) { write("ERROR", msg) }

    private static func write(_ level: String, _ msg: String) {
        let line = "\(fmt.string(from: Date())) \(level) \(msg)\n"
        if echoToStderr { FileHandle.standardError.write(line.data(using: .utf8)!) }
        queue.async {
            let url = URL(fileURLWithPath: path)
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            if let h = try? FileHandle(forWritingTo: url) {
                h.seekToEndOfFile(); h.write(line.data(using: .utf8)!); try? h.close()
            } else {
                try? line.data(using: .utf8)!.write(to: url)
            }
        }
    }
}
