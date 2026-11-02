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
        return .pass
    }

    /// True when the text is already mostly CJK (then EN→ZH makes no sense; translate to English instead).
    public static func isMostlyCJK(_ s: String) -> Bool {
        let cjk = cjkCount(s), latin = latinLetterCount(s)
        return cjk > 0 && Double(cjk) / Double(cjk + latin) > 0.5
    }
}
