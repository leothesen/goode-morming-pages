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
        static let tagProperty = "notionTagProperty"
        static let tagAllowsMultiple = "notionTagAllowsMultiple"
        static let tagOptions = "notionTagOptions"
        static let defaultTags = "defaultTags"
        static let lastEmoji = "lastEmoji"
        static let declinedRelocation = "declinedRelocation"
    }

    /// The select column tags are written to, discovered when you pick a
    /// destination in Settings.
    @Published var tagPropertyKey: String? {
        didSet { defaults.set(tagPropertyKey, forKey: Key.tagProperty) }
    }

    @Published var tagAllowsMultiple: Bool {
        didSet { defaults.set(tagAllowsMultiple, forKey: Key.tagAllowsMultiple) }
    }

    /// Options Notion already knows about. Only a convenience for the picker —
    /// Notion creates unknown names on write.
    @Published var tagOptions: [String] {
        didSet { defaults.set(tagOptions, forKey: Key.tagOptions) }
    }

    /// Pre-selected on every sync.
    @Published var defaultTags: [String] {
        didSet { defaults.set(defaultTags, forKey: Key.defaultTags) }
    }

    /// The emoji used last, offered again next time.
    @Published var lastEmoji: String {
        didSet { defaults.set(lastEmoji, forKey: Key.lastEmoji) }
    }

    /// Set once you've said no to moving the app into Applications.
    @Published var declinedRelocation: Bool {
        didSet { defaults.set(declinedRelocation, forKey: Key.declinedRelocation) }
    }

    var tagProperty: TagProperty? {
        guard let tagPropertyKey else { return nil }
        return TagProperty(
            key: tagPropertyKey,
            allowsMultiple: tagAllowsMultiple,
            options: tagOptions
        )
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
            Key.defaultTags: ["Morning pages"],
            Key.lastEmoji: "🌅",
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
        tagPropertyKey = defaults.string(forKey: Key.tagProperty)
        tagAllowsMultiple = defaults.bool(forKey: Key.tagAllowsMultiple)
        tagOptions = defaults.stringArray(forKey: Key.tagOptions) ?? []
        defaultTags = defaults.stringArray(forKey: Key.defaultTags) ?? ["Morning pages"]
        lastEmoji = defaults.string(forKey: Key.lastEmoji) ?? "🌅"
        declinedRelocation = defaults.bool(forKey: Key.declinedRelocation)

        // The first default was "morning-pages", which did not match the
        // "Morning pages" already in Notion — so syncing created a duplicate tag
        // beside the real one rather than using it.
        if defaultTags == ["morning-pages"] {
            defaultTags = ["Morning pages"]
        }
    }

    var isConfigured: Bool {
        dataSourceID != nil && Keychain.notionToken != nil
    }

    func apply(destination: NotionDestination) {
        dataSourceID = destination.id
        dataSourceName = destination.name
        titlePropertyKey = destination.titlePropertyKey
        tagPropertyKey = destination.tagProperty?.key
        tagAllowsMultiple = destination.tagProperty?.allowsMultiple ?? false
        tagOptions = destination.tagProperty?.options ?? []

        // Snap the defaults onto Notion's own spelling. Notion creates any name
        // it has not seen, so "morning pages" against an existing "Morning
        // pages" would quietly add a second, near-identical tag.
        defaultTags = defaultTags.map { tag in
            tagOptions.first { $0.caseInsensitiveCompare(tag) == .orderedSame } ?? tag
        }
    }

    /// Pulls the destination's schema again in the background.
    ///
    /// Tag options live in Notion and change there. Refreshing on launch and
    /// before each sync means you never have to go back to Settings and
    /// re-select the database just to pick up a new tag.
    func refreshSchema() async {
        guard !RuntimeEnvironment.isRunningTests else { return }
        guard let token = Keychain.notionToken, let id = dataSourceID else { return }
        guard let destination = try? await NotionClient(token: token).destination(id: id) else { return }
        await MainActor.run { apply(destination: destination) }
    }
}
