import Foundation

/// Cheap local checks that catch the two silent failures seen in testing: echoing the source and dropping content.
public struct ValidationResult: Equatable {
    public let ok: Bool
    public let reason: String?
    public static let pass = ValidationResult(ok: true, reason: nil)
    public static func fail(_ r: String) -> ValidationResult { ValidationResult(ok: false, reason: r) }
}

public enum Validator {
    public static func cjkCount(_ s: String) -> Int {
        s.unicodeScalars.reduce(0) { acc, u in
            let v = u.value
            return acc + ((0x4E00...0x9FFF).contains(v) || (0x3400...0x4DBF).contains(v) || (0x3000...0x303F).contains(v) || (0xFF00...0xFFEF).contains(v) ? 1 : 0)
        }
    }

    static func latinLetterCount(_ s: String) -> Int {
        s.unicodeScalars.reduce(0) { $0 + (($1.value >= 0x41 && $1.value <= 0x5A) || ($1.value >= 0x61 && $1.value <= 0x7A) ? 1 : 0) }
    }

    public static func normalize(_ s: String) -> String {
        s.lowercased().filter { !$0.isWhitespace && !$0.isPunctuation }
    }

    /// The model sometimes opens with an acknowledgement wrapped in the input's <source> tags
    /// ("<source>标签内的内容是需要翻译的源文本…</source>") before the translation. Remove that block and any
    /// stray leading/trailing tags. Returns the cleaned text and whether anything was removed.
    public static func stripPreamble(_ output: String, source: String = "") -> (text: String, stripped: String?) {
        var out = output
        var removed: [String] = []
        let ws = CharacterSet.whitespacesAndNewlines
        while true {
            let t = out.trimmingCharacters(in: ws)
            if t.hasPrefix("<source>"), let close = t.range(of: "</source>") {
                let rest = String(t[close.upperBound...]).trimmingCharacters(in: ws)
                if rest.isEmpty {
                    // The whole translation was wrapped in the tags: unwrap rather than discard.
                    removed.append("<source>…</source> wrapper")
                    out = String(t[t.index(t.startIndex, offsetBy: "<source>".count)..<close.lowerBound]).trimmingCharacters(in: ws)
                    break
                }
                removed.append(String(t[..<close.upperBound]))
                out = rest
            } else if t.hasPrefix("<source>") {
                removed.append("<source>"); out = String(t.dropFirst("<source>".count))
            } else if t.hasPrefix("</source>") {
                removed.append("</source>"); out = String(t.dropFirst("</source>".count))
            } else { out = t; break }
        }
        if out.hasSuffix("</source>") { removed.append("</source>"); out = String(out.dropLast("</source>".count)).trimmingCharacters(in: ws) }
        // A short opening line that talks about the tags or the act of translating ("标签内的内容是需要翻译的源文本，以下为译文：")
        // is an acknowledgement, not translation, unless the source itself is about translation or tags.
        let paras = out.components(separatedBy: "\n\n")
        if paras.count > 1, let first = paras.first?.trimmingCharacters(in: ws), first.count <= 80,
           isAcknowledgement(first), !sourceMentionsTranslation(source) {
            removed.append(first)
            out = paras.dropFirst().joined(separator: "\n\n").trimmingCharacters(in: ws)
        }
        return (out, removed.isEmpty ? nil : removed.joined(separator: " "))
    }

    static let ackMarkers = ["标签", "译文", "翻译", "source", "按规则", "按要求", "只输出", "不回答", "不是对我"]
    static func isAcknowledgement(_ line: String) -> Bool {
        let hits = ackMarkers.filter { line.contains($0) }.count
        return hits >= 2 || (hits == 1 && (line.hasSuffix("：") || line.hasSuffix(":") || line.contains("以下")))
    }
    static func sourceMentionsTranslation(_ source: String) -> Bool {
        let l = source.lowercased()
        return l.contains("translat") || l.contains("<source>") || l.contains("标签") || l.contains("译")
    }

    /// `expectCJK` is true when the target language is Chinese or Japanese.
    public static func validate(source: String, output: String, expectCJK: Bool = true) -> ValidationResult {
        let out = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if out.isEmpty { return .fail("empty output") }
        let srcLetters = latinLetterCount(source)
        // Mostly non-prose source (numbers, symbols, code): anything non-empty passes.
        if srcLetters < 12 { return .pass }
        let srcWords = source.split(whereSeparator: { $0.isWhitespace }).map { String($0) }
        // Short sources (labels, titles, identifiers, names) have too little signal for ratio checks; the panel
        // shows the result, and an unchanged result is marked as such rather than treated as an error.
        if srcWords.count < 8 && source.count < 60 { return .pass }
        if normalize(out) == normalize(source) { return .fail("output equals source (echo)") }
        let ratio = Double(out.count) / Double(max(source.count, 1))
        if ratio < 0.12 { return .fail("output too short (\(Int(ratio * 100))% of source)") }
        if ratio > 3.0 { return .fail("output too long (\(Int(ratio * 100))% of source)") }
        if expectCJK {
            let cjk = cjkCount(out)
            // Latin words carried over from the source (names, identifiers, product names) are not untranslated prose.
            let srcSet = Set(srcWords.map { normalize($0) })
            let carried = out.split(whereSeparator: { $0.isWhitespace }).filter { srcSet.contains(normalize(String($0))) }
            let outLetters = latinLetterCount(out) - carried.reduce(0) { $0 + latinLetterCount(String($1)) }
            if cjk == 0 { return .fail("no CJK characters in output") }
            if Double(cjk) / Double(cjk + max(0, outLetters)) < 0.35 { return .fail("too little CJK (\(cjk) cjk vs \(outLetters) new latin)") }
        }
        if out.contains("<system-reminder>") || out.contains("# Environment") || out.contains("工作目录") && !source.contains("工作目录") {
            return .fail("harness metadata leaked into output")
        }
        if !source.contains("<source>") && (out.contains("<source>") || out.contains("</source>")) {
            return .fail("source tag leaked into output (preamble)")
        }
        // A leading paragraph in the source language that is not in the source is the model talking to itself
        // ("Hmm, that's not right — the system says output only the translation…").
        if expectCJK, let first = out.components(separatedBy: "\n\n").first {
            let words = first.split(whereSeparator: { $0.isWhitespace }).count
            if cjkCount(first) == 0 && words >= 5 && latinLetterCount(first) > 20 && !normalize(source).contains(normalize(first)) {
                return .fail("commentary before translation (preamble)")
            }
        }
        return .pass
    }

    /// True when the text is already mostly CJK (then EN→ZH makes no sense; translate to English instead).
    public static func isMostlyCJK(_ s: String) -> Bool {
        let cjk = cjkCount(s), latin = latinLetterCount(s)
        return cjk > 0 && Double(cjk) / Double(cjk + latin) > 0.5
    }
}
