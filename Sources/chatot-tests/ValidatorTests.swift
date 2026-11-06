import Foundation
import ChatotCore

struct ValidatorTests {
    let src = "Can you explain why the daemon keeps one warm session per provider? We spawn the process once, then write one JSON line per request."

    func testGoodTranslationPasses() {
        let out = "你能解释一下为什么守护进程要为每个 provider 保留一个预热会话吗？我们只启动一次进程，然后每个请求写入一行 JSON。"
        expect(Validator.validate(source: src, output: out).ok)
    }

    func testEchoFails() {
        let r = Validator.validate(source: src, output: src)
        expect(!r.ok); expect(r.reason!.contains("echo"))
    }

    func testIdentifierEchoPasses() {
        expect(Validator.validate(source: "ANTHROPIC_API_KEY", output: "ANTHROPIC_API_KEY").ok)
        expect(Validator.validate(source: "https://example.com/some/path", output: "https://example.com/some/path").ok)
    }

    func testShortLabelWithNamePasses() {
        expect(Validator.validate(source: "Sign in to Claude", output: "登录 Claude").ok)
        expect(Validator.validate(source: "Claude: Sign in", output: "Claude：登录").ok)
    }

    func testCarriedOverNamesDoNotCountAsLatin() {
        let src = "Claude Code and Visual Studio Code are both made by companies with offices in San Francisco and Seattle, which matters."
        let out = "Claude Code 和 Visual Studio Code 都由在 San Francisco 和 Seattle 设有办公室的公司开发，这很重要。"
        expect(Validator.validate(source: src, output: out).ok)
    }

    func testMostlyCJKDetection() {
        expect(Validator.isMostlyCJK("这是一段中文文本，包含 API 一词。"))
        expect(!Validator.isMostlyCJK("This is English with one word: 中文."))
    }

    func testEnglishOutputFails() {
        let r = Validator.validate(source: src, output: "Sure, here is why the daemon keeps a warm session per provider: it avoids startup cost.")
        expect(!(r.ok))
    }

    func testTruncatedOutputFails() {
        let long = String(repeating: "This is a sentence about throughput and learners. ", count: 20)
        let r = Validator.validate(source: long, output: "吞吐量。")
        expect(!r.ok); expect(r.reason!.contains("short"))
    }

    func testHarnessLeakFails() {
        let r = Validator.validate(source: src, output: "你好。<system-reminder>x</system-reminder> 守护进程会话请求写入。")
        expect(!(r.ok))
    }

    func testNumericSourcePasses() {
        expect(Validator.validate(source: "2026-10-26 · 1,567 / 0.79", output: "2026-10-26 · 1,567 / 0.79").ok)
    }

    func testEmptyFails() {
        expect(!(Validator.validate(source: src, output: "  ").ok))
    }

    func testStripPreambleRemovesSourceAcknowledgement() {
        let (t, st) = Validator.stripPreamble("<source>标签内的内容是需要翻译的源文本，我按规则直接翻译。</source>\n\n- 健康状况：熵 1.39。")
        expect(t == "- 健康状况：熵 1.39。")
        expect(st?.hasPrefix("<source>") == true)
        let (t2, st2) = Validator.stripPreamble("健康状况：熵 1.39。")
        expect(t2 == "健康状况：熵 1.39。" && st2 == nil)
        expect(Validator.stripPreamble("<source>\n这是译文。\n</source>").text == "这是译文。")
        // Bare tag + plain acknowledgement line, then the translation.
        let (t3, st3) = Validator.stripPreamble("<source>\n标签内为需要翻译的英文内容，以下为译文。\n\n- 健康状况：熵 1.39。", source: "Health: entropy 1.39")
        expect(t3 == "- 健康状况：熵 1.39。" && st3?.contains("以下为译文") == true)
        let (t4, _) = Validator.stripPreamble("这段内容不是需要我回答的问题，按规则我只提供译文：\n\n健康状况：熵 1.39。", source: "Health: entropy 1.39")
        expect(t4 == "健康状况：熵 1.39。")
        // A source that is itself about translation keeps its first paragraph.
        let about = Validator.stripPreamble("译文如下的格式要求：\n\n第二段。", source: "Format requirements for the translation below:\n\nSecond paragraph.")
        expect(about.text.hasPrefix("译文如下"))
        // Ordinary first paragraphs are untouched.
        expect(Validator.stripPreamble("我们明天讨论这个标签的设计。\n\n第二段。", source: "We discuss this label's design tomorrow.\n\nSecond paragraph.").stripped == nil)
    }

    func testLeakedTagOrCommentaryFails() {
        let src = "Health: entropy 1.39, value loss 0.185, versus the heuristic 0.89 and the league 0.52. Nothing needs a decision from you now, I will report the result when it lands tonight."
        let good = "健康状况：熵 1.39，价值损失 0.185，对启发式 0.89，对联赛 0.52。目前无需你做任何决定，结果出来后我会汇报。"
        expect(Validator.validate(source: src, output: good).ok)
        expect(!Validator.validate(source: src, output: "<source>中的内容是要翻译的文本。</source>\n\n" + good).ok)
        expect(!Validator.validate(source: src, output: "Hmm, that's not right — the system says output only the translation with no preamble. Let me give the translation alone.\n\n" + good).ok)
        // A leading English line that is part of the source (kept untranslated, e.g. a command) is fine.
        let srcCode = "swift run chatot-tests --filter validator --verbose\n\nRun this before every commit, it takes about ten seconds on a laptop."
        expect(Validator.validate(source: srcCode, output: "swift run chatot-tests --filter validator --verbose\n\n每次提交前运行它，在笔记本上大约需要十秒。").ok)
    }
}
