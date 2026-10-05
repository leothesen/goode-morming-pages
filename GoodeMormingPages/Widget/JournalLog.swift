import Foundation

/// The days you wrote, remembered locally so the widget never waits on Notion.
///
/// Dates only. This is the one thing the app keeps about past sessions, and it
/// holds no text: Notion is still the only record of what you wrote. It is a
/// cache of Notion, reconciled against it on launch and every few hours.
struct JournalLog: Codable, Equatable {
    var days: Set<String> = []
    var lastReconciled: Date?

    /// The tag that makes a Notion page a morning's pages.
    static let tag = "Morning pages"

    /// Whether a sync with these tags is a morning's pages.
    ///
    /// A database with no tag column can't be filtered, so every page in it
    /// counts. Otherwise it has to carry the tag, matched the way Notion's own
    /// options are snapped in `Preferences.apply` — ignoring case.
    static func counts(tags: [String], hasTagColumn: Bool) -> Bool {
        guard hasTagColumn else { return true }
        return tags.contains { $0.caseInsensitiveCompare(tag) == .orderedSame }
    }

    /// Notion's days win, with one exception: today, if this Mac saw you sync.
    ///
    /// Notion's query can lag a page created seconds ago. Dropping today on
    /// that would flip the widget back to the prompt right after you wrote.
    static func reconciled(notion: Set<String>, local: Set<String>, today: String) -> Set<String> {
        local.contains(today) ? notion.union([today]) : notion
    }
}

/// Reads and writes the log beside the session buffer in Application Support.
enum JournalLogStore {
    static var defaultDirectory: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("GoodeMormingPages", isDirectory: true)
    }

    private static let fileName = "journal-days.json"

    static func load(from directory: URL?) -> JournalLog {
        guard let url = directory?.appendingPathComponent(fileName),
              let data = try? Data(contentsOf: url),
              let log = try? decoder.decode(JournalLog.self, from: data)
        else { return JournalLog() }
        return log
    }

    static func save(_ log: JournalLog, to directory: URL?) {
        guard let directory else { return }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try encoder.encode(log).write(to: directory.appendingPathComponent(fileName), options: .atomic)
        } catch {
            NSLog("[GoodeMormingPages] journal log save failed: \(error.localizedDescription)")
        }
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
