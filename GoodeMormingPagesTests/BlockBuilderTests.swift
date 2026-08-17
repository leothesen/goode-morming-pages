import XCTest
@testable import Goode_Morming_Pages

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

    func testBlankLinesBecomeEmptyParagraphs() {
        let blocks = BlockBuilder.blocks(from: "one\n\ntwo")
        XCTAssertEqual(blocks.count, 3)

        let middle = blocks[1]["paragraph"] as? [String: Any]
        let richText = middle?["rich_text"] as? [[String: Any]]
        XCTAssertEqual(richText?.count, 0, "a blank line should carry no rich text")
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
        let blocks = BlockBuilder.blocks(from: (0..<250).map(String.init).joined(separator: "\n"))
        let batches = BlockBuilder.batches(blocks)

        XCTAssertEqual(batches.count, 3)
        XCTAssertEqual(batches.map(\.count), [100, 100, 50])
        XCTAssertEqual(batches.flatMap { $0 }.count, blocks.count, "blocks lost in batching")
    }

    func testEmptyInputProducesNoBatches() {
        XCTAssertTrue(BlockBuilder.batches([]).isEmpty)
    }
}
