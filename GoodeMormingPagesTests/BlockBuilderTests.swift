import XCTest
@testable import GoodeMormingPages

final class BlockBuilderTests: XCTestCase {

    // MARK: - The 2000 character cap

    func testParagraphUnderLimitIsNotSplit() {
        let text = String(repeating: "a", count: 1_999)
        XCTAssertEqual(BlockBuilder.split(text).count, 1)
    }

    func testParagraphExactlyAtLimitIsNotSplit() {
        let text = String(repeating: "a", count: 2_000)
        XCTAssertEqual(BlockBuilder.split(text).count, 1)
    }

    func testParagraphOverLimitIsSplit() {
        let text = String(repeating: "a", count: 2_001)
        XCTAssertGreaterThan(BlockBuilder.split(text).count, 1)
    }

    func testNoPieceExceedsTheLimit() {
        // A realistic morning-pages paragraph: long, unbroken, full of words.
        let text = Array(repeating: "reflection", count: 900).joined(separator: " ")
        for piece in BlockBuilder.split(text) {
            XCTAssertLessThanOrEqual(piece.count, BlockBuilder.maxCharacters)
        }
    }

    func testSplitPrefersWordBoundaries() {
        let text = Array(repeating: "word", count: 900).joined(separator: " ")
        let pieces = BlockBuilder.split(text)
        // Breaking on whitespace means no piece starts or ends mid-word.
        for piece in pieces.dropLast() {
            XCTAssertFalse(piece.hasSuffix("wor"), "split landed inside a word")
        }
    }

    func testRunWithNoWhitespaceIsStillCappedNotPassedThrough() {
        // A pasted URL, or a held-down key. There is no word boundary to find,
        // so it must be cut at the limit rather than allowed through oversized.
        let text = String(repeating: "x", count: 5_000)
        let pieces = BlockBuilder.split(text)
        XCTAssertEqual(pieces.count, 3)
        for piece in pieces {
            XCTAssertLessThanOrEqual(piece.count, BlockBuilder.maxCharacters)
        }
        XCTAssertEqual(pieces.joined().count, 5_000, "no characters lost")
    }

    func testSplitLosesNoWordsWhenBreakingOnWhitespace() {
        let words = Array(repeating: "alpha", count: 900)
        let text = words.joined(separator: " ")
        let rejoined = BlockBuilder.split(text).joined(separator: " ")
        XCTAssertEqual(
            rejoined.split(separator: " ").count,
            words.count,
            "a word went missing across the split boundary"
        )
    }

    // MARK: - Block shape

    // MARK: - Line breaks versus new blocks

    func testConsecutiveLinesStayInOneBlock() {
        // Every newline used to become its own block, which Notion renders with
        // a visibly empty paragraph between each line.
        let blocks = BlockBuilder.blocks(from: "Hello\nHow is this working\nPretty well")
        XCTAssertEqual(blocks.count, 1, "single newlines should not split blocks")

        XCTAssertEqual(content(of: blocks[0]), "Hello\nHow is this working\nPretty well")
    }

    func testBlankLineStartsANewBlock() {
        let blocks = BlockBuilder.blocks(from: "first thought\n\nsecond thought")
        XCTAssertEqual(blocks.count, 2)
        XCTAssertEqual(content(of: blocks[0]), "first thought")
        XCTAssertEqual(content(of: blocks[1]), "second thought")
    }

    func testNoEmptyBlocksAreEmitted() {
        let blocks = BlockBuilder.blocks(from: "one\n\n\n\ntwo\n\n")
        XCTAssertEqual(blocks.count, 2, "runs of blank lines are separators, not content")
        for block in blocks {
            XCTAssertFalse(content(of: block)?.isEmpty ?? true)
        }
    }

    func testWhitespaceOnlyLinesCountAsBlank() {
        let blocks = BlockBuilder.blocks(from: "one\n   \ntwo")
        XCTAssertEqual(blocks.count, 2)
    }

    func testEmptyTextProducesNoBlocks() {
        XCTAssertTrue(BlockBuilder.blocks(from: "").isEmpty)
        XCTAssertTrue(BlockBuilder.blocks(from: "\n\n  \n").isEmpty)
    }

    private func content(of block: [String: Any]) -> String? {
        let paragraph = block["paragraph"] as? [String: Any]
        let richText = paragraph?["rich_text"] as? [[String: Any]]
        return (richText?.first?["text"] as? [String: Any])?["content"] as? String
    }

    func testBlockHasTheShapeNotionExpects() {
        guard let block = BlockBuilder.blocks(from: "hello").first else {
            return XCTFail("no block produced")
        }
        XCTAssertEqual(block["object"] as? String, "block")
        XCTAssertEqual(block["type"] as? String, "paragraph")

        let paragraph = block["paragraph"] as? [String: Any]
        let richText = paragraph?["rich_text"] as? [[String: Any]]
        let content = (richText?.first?["text"] as? [String: Any])?["content"] as? String
        XCTAssertEqual(content, "hello")
    }

    // MARK: - The 100 element cap

    func testBatchesRespectTheBlockArrayCap() {
        // Blank-line separated, because single newlines are line breaks inside a
        // block and would collapse all 250 of these into one.
        let text = (0..<250).map(String.init).joined(separator: "\n\n")
        let blocks = BlockBuilder.blocks(from: text)
        XCTAssertEqual(blocks.count, 250)

        let batches = BlockBuilder.batches(blocks)

        XCTAssertEqual(batches.count, 3)
        XCTAssertEqual(batches.map(\.count), [100, 100, 50])
        XCTAssertEqual(batches.flatMap { $0 }.count, blocks.count, "blocks lost in batching")
    }

    func testEmptyInputProducesNoBatches() {
        XCTAssertTrue(BlockBuilder.batches([]).isEmpty)
    }
}
