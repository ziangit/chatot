import Foundation
import ChatotCore

// Minimal test harness: Command Line Tools ship no XCTest / Testing module. Run with `swift run chatot-tests`.
var checks = 0
var failures = 0
func expect(_ condition: Bool, file: String = #file, line: Int = #line) {
    checks += 1
    if !condition { failures += 1; print("FAIL \(file):\(line)") }
}

ChunkerTests().testSplitsParagraphsAndKeepsOrder()
ChunkerTests().testGroupsSmallParagraphsUpToTarget()
ChunkerTests().testCodeFenceIsPassthroughEvenWithBlankLines()
ChunkerTests().testBoxTableIsPassthrough()
ChunkerTests().testMarkdownTableIsPassthrough()
ChunkerTests().testBulletListStaysTogether()
ConfigTests().testParseDotEnv()
ConfigTests().testEnvironmentOverrides()
ConfigTests().testGlossaryParse()
ConfigTests().testProviderSelection()
ConfigTests().testDescriptionRedactsAllKeys()
ValidatorTests().testGoodTranslationPasses()
ValidatorTests().testEchoFails()
ValidatorTests().testIdentifierEchoPasses()
ValidatorTests().testShortLabelWithNamePasses()
ValidatorTests().testCarriedOverNamesDoNotCountAsLatin()
ValidatorTests().testMostlyCJKDetection()
ValidatorTests().testEnglishOutputFails()
ValidatorTests().testTruncatedOutputFails()
ValidatorTests().testHarnessLeakFails()
ValidatorTests().testNumericSourcePasses()
ValidatorTests().testStripPreambleRemovesSourceAcknowledgement()
ValidatorTests().testLeakedTagOrCommentaryFails()
ValidatorTests().testEmptyFails()

print("\(checks) checks, \(failures) failures")
exit(failures == 0 ? 0 : 1)
