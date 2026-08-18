import XCTest
@testable import GoodeMormingPages

final class EmojiCatalogTests: XCTestCase {

    func testCatalogIsTheWholeSetNotACuratedHandful() {
        // It used to be about sixty hand-picked entries, which is why searching
        // for a gear came back empty.
        XCTAssertGreaterThan(EmojiCatalog.all.count, 1_000)
    }

    func testFindsTextPresentationEmojiByName() {
        // These default to text presentation and need a variation selector.
        // Filtering on isEmojiPresentation alone drops all of them silently.
        for term in ["gear", "airplane", "heart", "umbrella"] {
            XCTAssertFalse(
                EmojiCatalog.matching(term).isEmpty,
                "\"\(term)\" should match something"
            )
        }
    }

    func testFindsEmojiPresentationEmojiByName() {
        for term in ["rocket", "seedling", "hourglass", "brain"] {
            XCTAssertFalse(
                EmojiCatalog.matching(term).isEmpty,
                "\"\(term)\" should match something"
            )
        }
    }

    func testGearIsPresentAndRendersInColour() {
        let gear = EmojiCatalog.matching("gear").first { $0.name == "gear" }
        XCTAssertNotNil(gear, "the gear is the one that was reported missing")
        XCTAssertTrue(
            gear?.emoji.unicodeScalars.contains("\u{FE0F}") ?? false,
            "a text-presentation emoji needs a variation selector to render in colour"
        )
    }

    func testPastingAnEmojiFindsIt() {
        // With and without the variation selector, since what lands on the
        // clipboard varies by source.
        XCTAssertEqual(EmojiCatalog.matching("\u{2699}\u{FE0F}").first?.name, "gear")
        XCTAssertEqual(EmojiCatalog.matching("\u{2699}").first?.name, "gear")
        XCTAssertEqual(EmojiCatalog.matching("\u{1F680}").first?.name, "rocket")
    }

    func testEmptyQueryReturnsEverything() {
        XCTAssertEqual(EmojiCatalog.matching("").count, EmojiCatalog.all.count)
        XCTAssertEqual(EmojiCatalog.matching("   ").count, EmojiCatalog.all.count)
    }

    func testNoDuplicates() {
        let unique = Set(EmojiCatalog.all.map(\.emoji))
        XCTAssertEqual(unique.count, EmojiCatalog.all.count)
    }

    func testExcludesRegionalIndicatorsWhichRenderAsLetterBoxes() {
        // Alone they are not flags, just boxed letters.
        let regional = EmojiCatalog.all.filter { entry in
            entry.emoji.unicodeScalars.contains { (0x1F1E6...0x1F1FF).contains($0.value) }
        }
        XCTAssertTrue(regional.isEmpty)
    }
}
