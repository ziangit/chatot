import Foundation

/// User glossary: `term = translation` lines in `~/.config/chatot/glossary.txt`.
public enum Glossary {
    public static var path: String = NSString(string: "~/.config/chatot/glossary.txt").expandingTildeInPath

    public static func load() -> [String: String] {
        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else { return [:] }
        return parse(text)
    }

    public static func parse(_ text: String) -> [String: String] {
        var out: [String: String] = [:]
        for raw in text.split(separator: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            guard let eq = line.firstIndex(of: "=") else { continue }
            let k = line[..<eq].trimmingCharacters(in: .whitespaces)
            let v = line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces)
            if !k.isEmpty && !v.isEmpty { out[k] = v }
        }
        return out
    }
}
