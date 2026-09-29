import XCTest
@testable import GoodeMormingPages

/// The library is content, but content with rules: one voice, no repeats.
final class PromptLibraryTests: XCTestCase {

    func testLibraryIsTheFullSet() {
        XCTAssertEqual(PromptLibrary.themes.count, 17)
        XCTAssertEqual(PromptLibrary.all.count, 425)
    }

    func testNoPromptAppearsTwice() {
        let texts = PromptLibrary.all.map(\.text)
        XCTAssertEqual(Set(texts).count, texts.count)
    }

    func testEveryPromptIsOneQuestionInTheHouseVoice() {
        for prompt in PromptLibrary.all {
            XCTAssertTrue(prompt.text.hasSuffix("?"), prompt.text)
            // Lowercase throughout, including the first letter. "I" is the one
            // word that would be tempted, and it stays lowercase too.
            XCTAssertEqual(prompt.text, prompt.text.lowercased(), prompt.text)
            // Straight quotes look like typewriter marks in Garamond.
            XCTAssertFalse(prompt.text.contains("'"), prompt.text)
            XCTAssertFalse(prompt.text.contains("\""), prompt.text)
        }
    }

    func testPromptsFitTheTwoLineBox() {
        // The box is fixed at two lines so › never moves. A prompt long enough
        // to need three would be squeezed by the scale factor instead.
        let longest = PromptLibrary.all.map(\.text.count).max() ?? 0
        XCTAssertLessThanOrEqual(longest, 110)
    }
}

final class PromptDeckTests: XCTestCase {
    private var suite: String!
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        suite = "PromptDeckTests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
    }

    private let sample = (0..<10).map { Prompt(text: "prompt \($0)?", theme: "t") }

    private func makeDeck(seed: UInt64 = 42, prompts: [Prompt]? = nil) -> PromptDeck {
        PromptDeck(prompts: prompts ?? sample, defaults: defaults, makeSeed: { seed })
    }

    func testShuffleIsAPermutation() {
        let order = PromptDeck.shuffledOrder(count: 425, seed: 7)
        XCTAssertEqual(order.sorted(), Array(0..<425))
        XCTAssertNotEqual(order, Array(0..<425))
    }

    func testShuffleIsStableForASeed() {
        // A saved seed has to deal the same deck on every launch, forever.
        XCTAssertEqual(
            PromptDeck.shuffledOrder(count: 50, seed: 123),
            PromptDeck.shuffledOrder(count: 50, seed: 123)
        )
        XCTAssertNotEqual(
            PromptDeck.shuffledOrder(count: 50, seed: 123),
            PromptDeck.shuffledOrder(count: 50, seed: 124)
        )
    }

    func testFirstRevealShowsTheFirstCard() {
        let deck = makeDeck()
        deck.reveal()
        XCTAssertEqual(deck.position, 0)
        XCTAssertEqual(deck.displayPosition, 1)
        XCTAssertEqual(deck.current, sample[deck.order[0]])
    }

    func testRevealingAgainKeepsTheSamePrompt() {
        // Hiding the prompt and bringing it back is not asking for a new one.
        let deck = makeDeck()
        deck.reveal()
        let first = deck.current
        deck.reveal()
        XCTAssertEqual(deck.current, first)
    }

    func testEveryPromptOnceBeforeAnyRepeats() {
        let deck = makeDeck()
        deck.reveal()
        var seen = [deck.current]
        for _ in 1..<sample.count {
            deck.next()
            seen.append(deck.current)
        }
        XCTAssertEqual(Set(seen.map(\.text)).count, sample.count)

        deck.next()
        XCTAssertEqual(deck.current, seen[0], "wraps round to the start")
    }

    func testPreviousGoesBack() {
        let deck = makeDeck()
        deck.reveal()
        let first = deck.current
        deck.next()
        deck.previous()
        XCTAssertEqual(deck.current, first)

        deck.previous()
        XCTAssertEqual(deck.position, sample.count - 1, "wraps backwards too")
    }

    func testTomorrowCarriesOnFromToday() {
        let today = makeDeck(seed: 1)
        today.reveal()
        today.next()
        today.next()
        let lastSeen = today.position

        // A different seed proves the stored one is used, not a new deal.
        let tomorrow = makeDeck(seed: 999)
        XCTAssertEqual(tomorrow.order, today.order)
        tomorrow.reveal()
        XCTAssertEqual(tomorrow.position, lastSeen + 1)
    }

    func testChangingTheLibraryDealsANewDeck() {
        let before = makeDeck(seed: 1)
        before.reveal()
        before.next()

        // An index into the old order would point at the wrong prompts.
        let bigger = sample + [Prompt(text: "new?", theme: "t")]
        let after = makeDeck(seed: 2, prompts: bigger)
        XCTAssertEqual(after.order, PromptDeck.shuffledOrder(count: bigger.count, seed: 2))
        after.reveal()
        XCTAssertEqual(after.position, 0)
    }
}
