import Foundation
import ChatotCore

struct ConfigTests {
    func testParseDotEnv() {
        let d = Config.parseDotEnv("# c\nANTHROPIC_API_KEY=sk-ant-x\nexport A='q v'\nB = \"z\"\nbad line\n")
        expect(d["ANTHROPIC_API_KEY"] == "sk-ant-x")
        expect(d["A"] == "q v")
        expect(d["B"] == "z")
        expect(d["bad line"] == nil)
    }

    func testEnvironmentOverrides() {
        let c = Config.load(environment: ["CHATOT_PROVIDERS": "codex-cli, ollama", "CHATOT_TARGET_LANG": "Japanese", "CHATOT_CONCURRENCY": "3"])
        expect(c.providerOrder == ["codex-cli", "ollama"])
        expect(c.targetLanguage == "Japanese")
        expect(c.maxConcurrency == 3)
    }

    func testGlossaryParse() {
        let g = Glossary.parse("learner = 学习器\n# comment\nactor=actor（执行器）\n")
        expect(g["learner"] == "学习器")
        expect(g["actor"] == "actor（执行器）")
    }
}
