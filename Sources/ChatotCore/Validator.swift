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

    static func normalize(_ s: String) -> String {
        s.lowercased().filter { !$0.isWhitespace && !$0.isPunctuation }
    }

    /// `expectCJK` is true when the target language is Chinese or Japanese.
    public static func validate(source: String, output: String, expectCJK: Bool = true) -> ValidationResult {
        let out = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if out.isEmpty { return .fail("empty output") }
        let srcLetters = latinLetterCount(source)
        // Mostly non-prose source (numbers, symbols, code): anything non-empty passes.
        if srcLetters < 12 { return .pass }
        if normalize(out) == normalize(source) { return .fail("output equals source (echo)") }
        let ratio = Double(out.count) / Double(max(source.count, 1))
        if ratio < 0.12 { return .fail("output too short (\(Int(ratio * 100))% of source)") }
        if ratio > 3.0 { return .fail("output too long (\(Int(ratio * 100))% of source)") }
        if expectCJK {
            let cjk = cjkCount(out)
            let outLetters = latinLetterCount(out)
            // Letters that remain are typically identifiers and product names; translated prose must still be mostly CJK.
            if cjk == 0 { return .fail("no CJK characters in output") }
            if Double(cjk) / Double(cjk + outLetters) < 0.35 { return .fail("too little CJK (\(cjk) cjk vs \(outLetters) latin)") }
        }
        if out.contains("<system-reminder>") || out.contains("# Environment") || out.contains("工作目录") && !source.contains("工作目录") {
            return .fail("harness metadata leaked into output")
        }
        return .pass
    }
}
