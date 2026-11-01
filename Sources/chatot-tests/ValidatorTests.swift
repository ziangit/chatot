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
}
