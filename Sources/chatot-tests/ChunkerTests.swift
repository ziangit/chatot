import Foundation
import ChatotCore

struct ChunkerTests {
    func testSplitsParagraphsAndKeepsOrder() {
        let text = "Para one.\n\nPara two.\n\nPara three."
        let segs = Chunker.split(text, targetChars: 12)
        expect(segs.map { $0.text } == ["Para one.", "Para two.", "Para three."])
        expect(segs.allSatisfy { $0.kind == .translate })
    }

    func testGroupsSmallParagraphsUpToTarget() {
        let text = "A.\n\nB.\n\nC.\n\nD."
        let segs = Chunker.split(text, targetChars: 100)
        expect(segs.count == 1)
        expect(segs[0].text == "A.\n\nB.\n\nC.\n\nD.")
    }

    func testCodeFenceIsPassthroughEvenWithBlankLines() {
        let text = "Intro.\n\n```json\n{\n\n  \"a\": 1\n}\n```\n\nOutro."
        let segs = Chunker.split(text, targetChars: 5)
        expect(segs.count == 3)
        expect(segs[1].kind == .passthrough)
        expect(segs[1].text.hasPrefix("```json"))
        expect(segs[2].text == "Outro.")
    }

    func testBoxTableIsPassthrough() {
        let table = "┌───┬───┐\n│ a │ b │\n├───┼───┤\n│ 1 │ 2 │\n└───┴───┘"
        let text = "Before.\n\n\(table)\n\nAfter."
        let segs = Chunker.split(text, targetChars: 5)
        expect(segs.count == 3)
        expect(segs[1].kind == .passthrough)
        expect(segs[1].text == table)
    }

    func testMarkdownTableIsPassthrough() {
        let text = "| a | b |\n|---|---|\n| 1 | 2 |"
        expect(Chunker.isPassthrough(text))
    }

    func testBulletListStaysTogether() {
        let text = "Benefits:\n- one\n- two\nDone?"
        let segs = Chunker.split(text, targetChars: 700)
        expect(segs.count == 1)
        expect(segs[0].text == text)
    }
}
