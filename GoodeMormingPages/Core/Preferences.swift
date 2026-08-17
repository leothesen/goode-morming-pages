import Foundation
import Combine

/// The three text-input behaviours Ensō exposes as toggles. All off by default
/// except smart quotes, which suit a Garamond page and never interrupt you.
struct SpellingOptions: Equatable {
    var checkSpelling = false
    var autocorrect = false
    var smartQuotes = true
}

/// Everything that survives a relaunch except the Notion token, which lives in
/// the Keychain instead.
final class Preferences: ObservableObject {
    static let shared = Preferences()

    private enum Key {
        static let wordGoal = "wordGoal"
        static let checkSpelling = "checkSpelling"
        static let autocorrect = "autocorrect"
        static let smartQuotes = "smartQuotes"
        static let dataSourceID = "notionDataSourceID"
        static let dataSourceName = "notionDataSourceName"
        static let titleProperty = "notionTitleProperty"
    }

    /// 300 a day. A goal of 0 means "just show the count, no target".
    @Published var wordGoal: Int {
        didSet { defaults.set(wordGoal, forKey: Key.wordGoal) }
    }

    @Published var spelling: SpellingOptions {
        didSet {
            defaults.set(spelling.checkSpelling, forKey: Key.checkSpelling)
            defaults.set(spelling.autocorrect, forKey: Key.autocorrect)
            defaults.set(spelling.smartQuotes, forKey: Key.smartQuotes)
        }
    }

    /// The Notion data source pages get created in.
    @Published var dataSourceID: String? {
        didSet { defaults.set(dataSourceID, forKey: Key.dataSourceID) }
    }

    @Published var dataSourceName: String? {
        didSet { defaults.set(dataSourceName, forKey: Key.dataSourceName) }
    }

    /// The key of the destination's title property. Never assume "Name" — it is
    /// whatever the column is called, and renaming it in Notion breaks writes.
    @Published var titlePropertyKey: String? {
        didSet { defaults.set(titlePropertyKey, forKey: Key.titleProperty) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.wordGoal: 300,
            Key.smartQuotes: true,
        ])
        wordGoal = defaults.integer(forKey: Key.wordGoal)
        spelling = SpellingOptions(
            checkSpelling: defaults.bool(forKey: Key.checkSpelling),
            autocorrect: defaults.bool(forKey: Key.autocorrect),
            smartQuotes: defaults.bool(forKey: Key.smartQuotes)
        )
        dataSourceID = defaults.string(forKey: Key.dataSourceID)
        dataSourceName = defaults.string(forKey: Key.dataSourceName)
        titlePropertyKey = defaults.string(forKey: Key.titleProperty)
    }

    var isConfigured: Bool {
        dataSourceID != nil && Keychain.notionToken != nil
    }
}
