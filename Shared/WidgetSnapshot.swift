import Foundation

/// Everything the desktop widget shows, handed over by the app in one file.
///
/// Compiled into both the app and the widget. The widget is sandboxed and never
/// touches the network or the Keychain: the app, which is not sandboxed, writes
/// this file straight into the widget's own container and the widget reads it
/// from its Documents folder. That is the whole bridge — no App Group, which an
/// ad-hoc signed app has no Team ID to claim.
///
/// It carries only dates and the next prompt. Never a word of what you wrote.
struct WidgetSnapshot: Codable, Equatable {
    /// The prompt the app will show the next time you ask for one.
    var prompt: WidgetPrompt?
    /// Every local day you wrote on, as `JournalDay` keys.
    var writtenDays: [String]
    var updated: Date

    static let fileName = "snapshot.json"
    static let widgetBundleID = "co.leothesen.GoodeMormingPages.Widget"

    /// What the widget should be showing at `date`.
    func face(on date: Date, calendar: Calendar = .current) -> WidgetFace {
        let written = Set(writtenDays)
        guard written.contains(JournalDay.key(for: date, calendar: calendar)) else {
            return .prompt(prompt)
        }
        return .month(
            MonthSummary(
                date: date,
                cells: MonthGrid.cells(for: date, written: written, calendar: calendar),
                thisMonth: MonthGrid.count(in: date, written: written, calendar: calendar),
                allTime: written.count
            )
        )
    }

    // MARK: - Reading and writing

    /// The widget reads from its own sandbox.
    static func read(from directory: URL? = sandboxDocuments) -> WidgetSnapshot? {
        guard let url = directory?.appendingPathComponent(fileName),
              let data = try? Data(contentsOf: url)
        else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WidgetSnapshot.self, from: data)
    }

    func write(to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(self).write(
            to: directory.appendingPathComponent(Self.fileName),
            options: .atomic
        )
    }

    static var sandboxDocuments: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }

    /// Where the widget's sandbox lives, seen from outside it. Only the app,
    /// which is not sandboxed, can write here.
    static var widgetContainerDocuments: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers/\(widgetBundleID)/Data/Documents", isDirectory: true)
    }
}

struct WidgetPrompt: Codable, Equatable {
    let text: String
    let theme: String
}

enum WidgetFace: Equatable {
    /// Not written yet today. `nil` until the app has run once.
    case prompt(WidgetPrompt?)
    case month(MonthSummary)
}

struct MonthSummary: Equatable {
    let date: Date
    let cells: [MonthGrid.Cell]
    let thisMonth: Int
    let allTime: Int
}

/// A day as the calendar on your Mac sees it, written `yyyy-MM-dd`.
///
/// Days are decided where you are, at your midnight. A page made at 00:30 is
/// the new day's page, whatever time zone Notion stores it in.
enum JournalDay {
    static func key(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04ld-%02ld-%02ld", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}

/// The month as a Monday-first grid, the way the widget draws it.
enum MonthGrid {
    enum Cell: Equatable {
        /// Padding before the 1st, so the 1st lands under its weekday.
        case blank
        case written
        case missed
        /// Later this month.
        case ahead
        case today(written: Bool)
    }

    static func cells(for date: Date, written: Set<String>, calendar: Calendar = .current) -> [Cell] {
        guard let interval = calendar.dateInterval(of: .month, for: date),
              let days = calendar.range(of: .day, in: .month, for: date)
        else { return [] }

        // .weekday counts Sunday as 1. Monday-first wants Monday as 0.
        let firstWeekday = calendar.component(.weekday, from: interval.start)
        let lead = (firstWeekday + 5) % 7
        let today = calendar.component(.day, from: date)

        var cells = Array(repeating: Cell.blank, count: lead)
        for day in days {
            guard let dayDate = calendar.date(byAdding: .day, value: day - 1, to: interval.start) else { continue }
            let wrote = written.contains(JournalDay.key(for: dayDate, calendar: calendar))
            if day == today {
                cells.append(.today(written: wrote))
            } else if day > today {
                cells.append(.ahead)
            } else {
                cells.append(wrote ? .written : .missed)
            }
        }
        return cells
    }

    static func count(in date: Date, written: Set<String>, calendar: Calendar = .current) -> Int {
        let prefix = String(JournalDay.key(for: date, calendar: calendar).prefix(8))
        return written.filter { $0.hasPrefix(prefix) }.count
    }
}
