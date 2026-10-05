import XCTest
@testable import GoodeMormingPages

/// A fixed calendar, so days are decided the same way on every machine.
private var calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Africa/Johannesburg")!
    return calendar
}()

private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 9) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
}

final class JournalDayTests: XCTestCase {

    func testKeysAreLocalDays() {
        XCTAssertEqual(JournalDay.key(for: date(2026, 10, 5), calendar: calendar), "2026-10-05")
    }

    func testAPageJustAfterLocalMidnightIsTheNewDay() throws {
        // 23:30 UTC on the 4th is 01:30 on the 5th in Cape Town.
        let created = try XCTUnwrap(NotionClient.parseTimestamp("2026-10-04T23:30:00.000Z"))
        XCTAssertEqual(JournalDay.key(for: created, calendar: calendar), "2026-10-05")
    }

    func testTimestampsParseWithOrWithoutFractions() {
        XCTAssertNotNil(NotionClient.parseTimestamp("2026-10-05T07:42:00.000Z"))
        XCTAssertNotNil(NotionClient.parseTimestamp("2026-10-05T07:42:00Z"))
        XCTAssertNil(NotionClient.parseTimestamp("yesterday"))
    }
}

final class MonthGridTests: XCTestCase {
    private let october5 = date(2026, 10, 5)

    func testOctoberStartsUnderThursday() {
        // October 2026 begins on a Thursday: three blanks for Mon–Wed.
        let cells = MonthGrid.cells(for: october5, written: [], calendar: calendar)
        XCTAssertEqual(Array(cells.prefix(3)), [.blank, .blank, .blank])
        XCTAssertEqual(cells.count, 3 + 31)
    }

    func testDaysAreWrittenMissedTodayOrAhead() {
        let written: Set = ["2026-10-01", "2026-10-02", "2026-10-05"]
        let cells = MonthGrid.cells(for: october5, written: written, calendar: calendar)
        let days = Array(cells.dropFirst(3))
        XCTAssertEqual(Array(days.prefix(6)), [
            .written, .written, .missed, .missed, .today(written: true), .ahead,
        ])
        XCTAssertEqual(days.last, .ahead)
    }

    func testAMonthStartingOnMondayHasNoBlanks() {
        // June 2026 begins on a Monday.
        let cells = MonthGrid.cells(for: date(2026, 6, 10), written: [], calendar: calendar)
        XCTAssertNotEqual(cells.first, .blank)
        XCTAssertEqual(cells.count, 30)
    }

    func testThisMonthCountsOnlyThisMonth() {
        let written: Set = ["2026-09-30", "2026-10-01", "2026-10-05", "2025-10-05"]
        XCTAssertEqual(MonthGrid.count(in: october5, written: written, calendar: calendar), 2)
    }
}

final class WidgetSnapshotTests: XCTestCase {
    private let prompt = WidgetPrompt(text: "what is here?", theme: "this moment")

    func testThePromptUntilYouHaveWritten() {
        let snapshot = WidgetSnapshot(prompt: prompt, writtenDays: ["2026-10-04"], updated: Date())
        XCTAssertEqual(snapshot.face(on: date(2026, 10, 5), calendar: calendar), .prompt(prompt))
    }

    func testTheMonthOnceYouHave() {
        let snapshot = WidgetSnapshot(
            prompt: prompt,
            writtenDays: ["2025-12-31", "2026-10-04", "2026-10-05"],
            updated: Date()
        )
        guard case .month(let summary) = snapshot.face(on: date(2026, 10, 5), calendar: calendar) else {
            return XCTFail("expected the month")
        }
        XCTAssertEqual(summary.thisMonth, 2)
        XCTAssertEqual(summary.allTime, 3, "the all-time total, not this month's")
    }

    func testMidnightTurnsTheDayOverWithoutTheApp() {
        // The widget re-reads the same snapshot at midnight. Yesterday's
        // pages must not keep today's prompt away.
        let snapshot = WidgetSnapshot(prompt: prompt, writtenDays: ["2026-10-05"], updated: Date())
        XCTAssertEqual(snapshot.face(on: date(2026, 10, 6, 0), calendar: calendar), .prompt(prompt))
    }

    func testRoundTripsThroughDisk() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let snapshot = WidgetSnapshot(
            prompt: prompt,
            writtenDays: ["2026-10-05"],
            updated: Date(timeIntervalSince1970: 1_791_190_000)
        )
        try snapshot.write(to: directory)
        XCTAssertEqual(WidgetSnapshot.read(from: directory), snapshot)
    }

    func testTheWidgetContainerIsTheExtensionsOwn() {
        XCTAssertTrue(WidgetSnapshot.widgetContainerDocuments.path.hasSuffix(
            "Library/Containers/co.leothesen.GoodeMormingPages.Widget/Data/Documents"
        ))
    }
}

final class JournalLogTests: XCTestCase {

    func testOnlyTaggedSyncsCount() {
        XCTAssertTrue(JournalLog.counts(tags: ["Morning pages"], hasTagColumn: true))
        XCTAssertTrue(JournalLog.counts(tags: ["work", "morning pages"], hasTagColumn: true))
        XCTAssertFalse(JournalLog.counts(tags: ["work"], hasTagColumn: true))
        XCTAssertFalse(JournalLog.counts(tags: [], hasTagColumn: true))
    }

    func testWithoutATagColumnEverySyncCounts() {
        XCTAssertTrue(JournalLog.counts(tags: [], hasTagColumn: false))
    }

    func testNotionIsTheRecord() {
        // A day deleted in Notion goes; a day only Notion knows about arrives.
        let merged = JournalLog.reconciled(
            notion: ["2026-10-01", "2026-10-03"],
            local: ["2026-10-01", "2026-10-02"],
            today: "2026-10-05"
        )
        XCTAssertEqual(merged, ["2026-10-01", "2026-10-03"])
    }

    func testTodaySurvivesANotionThatHasNotCaughtUp() {
        let merged = JournalLog.reconciled(
            notion: ["2026-10-01"],
            local: ["2026-10-01", "2026-10-05"],
            today: "2026-10-05"
        )
        XCTAssertEqual(merged, ["2026-10-01", "2026-10-05"])
    }
}

@MainActor
final class WidgetBridgeTests: XCTestCase {
    /// XCTest makes a fresh instance per test, so each gets its own folder.
    private let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)

    private func makeBridge() -> WidgetBridge {
        let directory = self.directory
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return WidgetBridge(
            logDirectory: directory.appendingPathComponent("log"),
            widgetDirectory: directory.appendingPathComponent("widget"),
            isLive: false
        )
    }

    private var published: WidgetSnapshot? {
        WidgetSnapshot.read(from: directory.appendingPathComponent("widget"))
    }

    func testASyncShowsUpInTheWidgetAtOnce() {
        let bridge = makeBridge()
        bridge.setPrompt(Prompt(text: "what is here?", theme: "this moment"))
        bridge.recordSync(tags: ["Morning pages"], hasTagColumn: true)

        let today = JournalDay.key(for: Date())
        XCTAssertEqual(published?.writtenDays, [today])
        XCTAssertEqual(published?.prompt, WidgetPrompt(text: "what is here?", theme: "this moment"))
    }

    func testAnUntaggedSyncLeavesTheWidgetAlone() {
        let bridge = makeBridge()
        bridge.recordSync(tags: ["work"], hasTagColumn: true)
        XCTAssertTrue(bridge.writtenDays.isEmpty)
    }

    func testTheDaysSurviveARelaunch() {
        makeBridge().recordSync(tags: ["Morning pages"], hasTagColumn: true)
        XCTAssertEqual(makeBridge().writtenDays, [JournalDay.key(for: Date())])
    }
}

final class NextSessionPromptTests: XCTestCase {
    private var suite: String!
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        suite = "NextSessionPromptTests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
    }

    private let sample = (0..<10).map { Prompt(text: "prompt \($0)?", theme: "t") }

    func testTheWidgetOffersWhatTheNextLaunchShows() {
        let today = PromptDeck(prompts: sample, defaults: defaults, makeSeed: { 3 })
        today.reveal()
        today.next()
        let offered = today.nextSessionPrompt

        let tomorrow = PromptDeck(prompts: sample, defaults: defaults, makeSeed: { 99 })
        tomorrow.reveal()
        XCTAssertEqual(tomorrow.current, offered)
    }

    func testBeforeAnyPromptHasBeenShownItIsTheFirstCard() {
        let deck = PromptDeck(prompts: sample, defaults: defaults, makeSeed: { 3 })
        XCTAssertEqual(deck.nextSessionPrompt, sample[deck.order[0]])
    }
}
