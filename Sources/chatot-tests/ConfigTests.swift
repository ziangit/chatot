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
        let c = Config.load(environment: ["CHATOT_TARGET_LANG": "Japanese", "CHATOT_CONCURRENCY": "3"])
        expect(c.targetLanguage == "Japanese")
        expect(c.maxConcurrency == 3)
    }

    func testGlossaryParse() {
        let g = Glossary.parse("learner = 学习器\n# comment\nactor=actor（执行器）\n")
        expect(g["learner"] == "学习器")
        expect(g["actor"] == "actor（执行器）")
    }

    func testProviderSelection() {
        let claude = Translator.makeProviders(config: Config.load(environment: ["ANTHROPIC_API_KEY": "k"]))
        expect(claude.map(\.id) == ["claude-api"] || claude.map(\.id) == ["claude"])
        let gpt = Translator.makeProviders(config: Config.load(environment: ["CHATOT_PROVIDER": "chatgpt", "OPENAI_API_KEY": "k"]))
        expect(gpt.map(\.id) == ["chatgpt"] && gpt.first?.supportsImages == true)
        let ds = Translator.makeProviders(config: Config.load(environment: ["CHATOT_PROVIDER": "deepseek", "DEEPSEEK_API_KEY": "k", "CHATOT_DEEPSEEK_MODEL": "deepseek-reasoner"]))
        expect(ds.map(\.id) == ["deepseek"] && ds.first?.supportsImages == false)
        expect((ds.first as? OpenAICompatibleProvider)?.model == "deepseek-reasoner")
        let none = Translator.makeProviders(config: Config.load(environment: ["CHATOT_PROVIDER": "chatgpt"]))
        expect(none.isEmpty)
    }
}
