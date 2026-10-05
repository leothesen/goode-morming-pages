import Foundation
import WidgetKit

/// Keeps the desktop widget's snapshot current.
///
/// The widget can't reach Notion or the Keychain, so the app does the work and
/// hands over the result: the next prompt, and the days you wrote. It writes on
/// launch, whenever the deck moves, after a sync, and after each reconcile.
///
/// The app usually quits when its window closes, so the widget can't count on
/// it being around at midnight. It doesn't need to: the snapshot holds dates,
/// and the widget works out for itself whether today is one of them.
@MainActor
final class WidgetBridge {
    static let shared: WidgetBridge = {
        guard RuntimeEnvironment.isRunningTests else { return WidgetBridge() }
        let scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("GoodeMormingPagesTests-\(UUID().uuidString)", isDirectory: true)
        return WidgetBridge(logDirectory: scratch, widgetDirectory: scratch, isLive: false)
    }()

    /// How often an open app checks the cache against Notion.
    static let reconcileInterval: TimeInterval = 4 * 60 * 60

    private var log: JournalLog
    private var prompt: WidgetPrompt?

    private let logDirectory: URL?
    private let widgetDirectory: URL
    /// Off under XCTest. The test host is the real app, and a test run must
    /// neither call Notion nor reload the real widget.
    private let isLive: Bool

    init(
        logDirectory: URL? = JournalLogStore.defaultDirectory,
        widgetDirectory: URL = WidgetSnapshot.widgetContainerDocuments,
        isLive: Bool = !RuntimeEnvironment.isRunningTests
    ) {
        self.logDirectory = logDirectory
        self.widgetDirectory = widgetDirectory
        self.isLive = isLive
        log = JournalLogStore.load(from: logDirectory)
    }

    var writtenDays: Set<String> { log.days }

    func setPrompt(_ next: Prompt) {
        let prompt = WidgetPrompt(text: next.text, theme: next.theme)
        guard prompt != self.prompt else { return }
        self.prompt = prompt
        publish()
    }

    /// Marks today as written straight away, without waiting for a reconcile.
    func recordSync(tags: [String], hasTagColumn: Bool, at date: Date = Date()) {
        guard JournalLog.counts(tags: tags, hasTagColumn: hasTagColumn) else { return }
        log.days.insert(JournalDay.key(for: date))
        JournalLogStore.save(log, to: logDirectory)
        publish()
    }

    /// Replaces the cache with what Notion says, then repeats every few hours
    /// for as long as the calling task lives.
    func keepReconciling(preferences: Preferences) async {
        while !Task.isCancelled {
            await reconcile(preferences: preferences)
            try? await Task.sleep(nanoseconds: UInt64(Self.reconcileInterval * 1_000_000_000))
        }
    }

    func reconcile(preferences: Preferences) async {
        guard isLive,
              let token = Keychain.notionToken,
              let dataSourceID = preferences.dataSourceID
        else { return }

        do {
            let tagProperty = preferences.tagProperty
            // Notion matches option names exactly, so ask in its spelling.
            let tag = tagProperty?.options.first {
                $0.caseInsensitiveCompare(JournalLog.tag) == .orderedSame
            } ?? JournalLog.tag
            let dates = try await NotionClient(token: token).creationDates(
                dataSourceID: dataSourceID, tagProperty: tagProperty, tag: tag
            )

            log.days = JournalLog.reconciled(
                notion: Set(dates.map { JournalDay.key(for: $0) }),
                local: log.days,
                today: JournalDay.key(for: Date())
            )
            log.lastReconciled = Date()
            JournalLogStore.save(log, to: logDirectory)
            publish()
        } catch {
            // The cache stands until the next attempt. A widget a few hours
            // stale is fine; one that empties on a dropped connection is not.
            NSLog("[GoodeMormingPages] widget reconcile failed: \(error.localizedDescription)")
        }
    }

    private func publish() {
        let snapshot = WidgetSnapshot(prompt: prompt, writtenDays: log.days.sorted(), updated: Date())
        do {
            try snapshot.write(to: widgetDirectory)
        } catch {
            // The widget's container belongs to another bundle, and macOS
            // privacy protection can refuse the write. Say so rather than let
            // the widget go quietly stale.
            NSLog("[GoodeMormingPages] widget snapshot write failed: \(error.localizedDescription)")
            return
        }
        guard isLive else { return }
        WidgetCenter.shared.reloadAllTimelines()
    }
}
