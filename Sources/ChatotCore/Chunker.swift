import Foundation

/// A piece of the source document. Passthrough segments (tables, code fences) are shown unchanged.
public struct Segment: Equatable, Identifiable {
    public enum Kind: Equatable { case translate, passthrough }
    public let id: Int
    public let kind: Kind
    public let text: String
    public init(id: Int, kind: Kind, text: String) { self.id = id; self.kind = kind; self.text = text }
}

/// Splits text into paragraph groups of roughly `targetChars`, keeping tables and code blocks intact and untranslated.
public enum Chunker {
    public static func split(_ text: String, targetChars: Int = 700) -> [Segment] {
        let blocks = blocksOf(text)
        var segments: [Segment] = []
        var pending: [String] = []
        var pendingLen = 0
        func flush() {
            if !pending.isEmpty {
                segments.append(Segment(id: segments.count, kind: .translate, text: pending.joined(separator: "\n\n")))
                pending.removeAll(); pendingLen = 0
            }
        }
        for b in blocks {
            if isPassthrough(b) {
                flush()
                segments.append(Segment(id: segments.count, kind: .passthrough, text: b))
                continue
            }
            if pendingLen > 0 && pendingLen + b.count > targetChars { flush() }
            pending.append(b); pendingLen += b.count
            if pendingLen >= targetChars { flush() }
        }
        flush()
        return segments
    }

    /// Paragraph blocks separated by blank lines; a fenced code block is one block regardless of blank lines inside.
    static func blocksOf(_ text: String) -> [String] {
        let lines = text.replacingOccurrences(of: "\r\n", with: "\n").split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var blocks: [String] = []
        var cur: [String] = []
        var inFence = false
        var inTable = false
        func push() {
            let joined = cur.joined(separator: "\n")
            if !joined.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { blocks.append(joined) }
            cur.removeAll()
        }
        for line in lines {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("```") {
                if inFence { cur.append(line); push(); inFence = false } else { push(); inFence = true; cur.append(line) }
                continue
            }
            if inFence { cur.append(line); continue }
            let tableLine = isTableLine(t)
            if tableLine != inTable { push(); inTable = tableLine }
            if t.isEmpty {
                if inTable { inTable = false }
                push()
            } else {
                cur.append(line)
            }
        }
        push()
        return blocks
    }

    static func isTableLine(_ t: String) -> Bool {
        if t.isEmpty { return false }
        let boxChars: Set<Character> = ["│", "┌", "┐", "└", "┘", "├", "┤", "┬", "┴", "┼", "─", "║", "╔", "╗", "╚", "╝", "═"]
        if let f = t.first, boxChars.contains(f) { return true }
        if t.hasPrefix("|") && t.hasSuffix("|") { return true }
        return false
    }

    public static func isPassthrough(_ block: String) -> Bool {
        let t = block.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("```") { return true }
        let lines = t.split(separator: "\n")
        guard !lines.isEmpty else { return false }
        let tableLines = lines.filter { isTableLine($0.trimmingCharacters(in: .whitespaces)) }.count
        return tableLines * 2 >= lines.count && lines.count >= 2
    }
}
