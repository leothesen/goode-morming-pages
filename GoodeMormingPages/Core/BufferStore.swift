import Foundation

/// Holds the one unsynced session across a quit or a crash.
///
/// This is **not** an archive. There is no history, no folder of past days —
/// Notion is the only record, by design. This file exists so that a crash at
/// minute thirty doesn't cost you the session, and it is deleted the moment a
/// sync is confirmed.
enum BufferStore {
    private static var directory: URL? {
        guard let base = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first else { return nil }
        return base.appendingPathComponent("GoodeMormingPages", isDirectory: true)
    }

    private static var file: URL? {
        directory?.appendingPathComponent("session.txt")
    }

    static func load() -> String {
        guard let file, let text = try? String(contentsOf: file, encoding: .utf8) else { return "" }
        return text
    }

    static func save(_ text: String) {
        guard let directory, let file else { return }
        do {
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true
            )
            try text.write(to: file, atomically: true, encoding: .utf8)
        } catch {
            // A failed autosave must never interrupt writing. The text is still
            // on screen, and Copy is one keystroke away.
            NSLog("[GoodeMormingPages] buffer save failed: \(error.localizedDescription)")
        }
    }

    /// Called only after Notion has confirmed the page and every block landed.
    static func clear() {
        guard let file else { return }
        try? FileManager.default.removeItem(at: file)
    }
}
