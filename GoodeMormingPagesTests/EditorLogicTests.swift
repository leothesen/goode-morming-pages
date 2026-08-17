import XCTest
@testable import GoodeMormingPages

final class WordCountTests: XCTestCase {

    func testEmptyBufferCountsZero() {
        // Ensō reports 1 here, because "".split(/\s+/) yields [""]. Opening a
        // session on "1 / 300" is wrong.
        XCTAssertEqual(WordCount.count(""), 0)
        XCTAssertEqual(WordCount.count("   "), 0)
        XCTAssertEqual(WordCount.count("\n\n"), 0)
    }

    func testCountsWords() {
        XCTAssertEqual(WordCount.count("one"), 1)
        XCTAssertEqual(WordCount.count("one two three"), 3)
    }

    func testCollapsesRunsOfWhitespace() {
        XCTAssertEqual(WordCount.count("one    two\n\nthree\tfour"), 4)
    }

    func testIgnoresLeadingAndTrailingWhitespace() {
        XCTAssertEqual(WordCount.count("  padded words  "), 2)
    }
}

final class MetricsTests: XCTestCase {

    func testLineHeightMatchesEnso() {
        // 22px root × 1.6 line unit.
        XCTAssertEqual(Metrics.lineHeight, 35.2, accuracy: 0.001)
    }

    func testWindowIsFiveLinesTall() {
        XCTAssertEqual(Metrics.windowHeight, 176, accuracy: 0.001)
        XCTAssertEqual(Metrics.scrimOpacities.count, Metrics.scrimLines)
    }

    func testEmptyBufferPutsTheCaretOnTheBottomLine() {
        // The whole point of bottom-anchoring: with nothing written, the first
        // line must sit in the one uncovered slot, not under the 0.98 scrim.
        let offset = Metrics.textOffset(caretLineMaxY: Metrics.lineHeight)
        XCTAssertEqual(offset, Metrics.windowHeight - Metrics.lineHeight, accuracy: 0.001)
        XCTAssertEqual(offset, 140.8, accuracy: 0.001)
    }

    func testFullWindowSitsFlush() {
        // Five lines written: nothing to offset, the text fills the window.
        let offset = Metrics.textOffset(caretLineMaxY: Metrics.lineHeight * 5)
        XCTAssertEqual(offset, 0, accuracy: 0.001)
    }

    func testLongerSessionScrollsUp() {
        // Eight lines in, the text has moved up by three line heights.
        let offset = Metrics.textOffset(caretLineMaxY: Metrics.lineHeight * 8)
        XCTAssertEqual(offset, -Metrics.lineHeight * 3, accuracy: 0.001)
        XCTAssertLessThan(offset, 0)
    }
}
