import Combine
import Foundation

struct Prompt: Equatable {
    let text: String
    let theme: String
}

struct PromptTheme {
    let name: String
    let prompts: [String]
}

/// The whole library, shuffled once and walked in order.
///
/// A fresh random pick every time repeats itself long before you have seen
/// everything -- with 425 prompts, you would expect a repeat within the first
/// few weeks. A shuffled deck shows every prompt once before any comes round
/// again, and ‹ can always go back to the one you just passed.
///
/// The shuffle and your place in it survive a relaunch, so tomorrow carries on
/// where today stopped rather than dealing a new deck. Only a change in the
/// library's size deals a new one: an index into the old order would point at
/// different prompts in the new one.
final class PromptDeck: ObservableObject {
    /// Which card in `order` is showing. -1 until the first prompt is ever shown.
    @Published private(set) var position: Int

    let prompts: [Prompt]
    private(set) var order: [Int]

    /// Once per launch, asking for a prompt moves past the one you saw last
    /// time. After that, showing and hiding it again keeps the same prompt.
    private var hasRevealedThisSession = false

    private let defaults: UserDefaults

    private enum Key {
        static let seed = "promptDeckSeed"
        static let count = "promptDeckCount"
        static let position = "promptDeckPosition"
    }

    init(
        prompts: [Prompt] = PromptLibrary.all,
        defaults: UserDefaults = .standard,
        makeSeed: () -> UInt64 = { UInt64.random(in: .min ... .max) }
    ) {
        self.prompts = prompts
        self.defaults = defaults

        let storedSeed = defaults.object(forKey: Key.seed) as? Int
        if let storedSeed, defaults.integer(forKey: Key.count) == prompts.count {
            order = Self.shuffledOrder(count: prompts.count, seed: UInt64(bitPattern: Int64(storedSeed)))
            let stored = defaults.integer(forKey: Key.position)
            position = (-1..<prompts.count).contains(stored) ? stored : -1
        } else {
            let seed = makeSeed()
            order = Self.shuffledOrder(count: prompts.count, seed: seed)
            position = -1
            defaults.set(Int(Int64(bitPattern: seed)), forKey: Key.seed)
            defaults.set(prompts.count, forKey: Key.count)
            defaults.set(position, forKey: Key.position)
        }
    }

    var current: Prompt {
        prompts[order[max(position, 0)]]
    }

    /// The prompt's place in the deck, counted from one, for the label.
    var displayPosition: Int { max(position, 0) + 1 }

    /// Called when prompts are turned on.
    func reveal() {
        guard !hasRevealedThisSession else { return }
        hasRevealedThisSession = true
        next()
    }

    func next() {
        move(to: (position + 1) % prompts.count)
    }

    func previous() {
        move(to: (max(position, 0) - 1 + prompts.count) % prompts.count)
    }

    private func move(to newPosition: Int) {
        hasRevealedThisSession = true
        position = newPosition
        defaults.set(position, forKey: Key.position)
    }

    /// Fisher–Yates over `0..<count`, driven by SplitMix64.
    ///
    /// Written out rather than using `shuffled(using:)`, whose algorithm the
    /// standard library does not promise to keep. If it changed under an OS
    /// update, a saved seed would quietly deal a different deck.
    static func shuffledOrder(count: Int, seed: UInt64) -> [Int] {
        var order = Array(0..<count)
        var state = seed
        func nextRandom() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
        for i in stride(from: count - 1, to: 0, by: -1) {
            let j = Int(nextRandom() % UInt64(i + 1))
            order.swapAt(i, j)
        }
        return order
    }
}
