import AppKit
import SwiftUI
import WidgetKit

/// The desktop widget: today's prompt until you've written, then your month.
///
/// Drawn in the primary colour at a few opacities on the standard widget
/// background, and nothing else. macOS does the rest — light, dark, clear and
/// tinted all come from the system, so a colour of our own would only be
/// flattened by it.
@main
struct MorningPagesWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MorningPagesWidget", provider: JournalProvider()) { entry in
            JournalWidgetView(entry: entry)
        }
        .configurationDisplayName("Morning Pages")
        .description("Today's prompt until you've written, then your month.")
        .supportedFamilies([.systemSmall])
    }
}

struct JournalEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

struct JournalProvider: TimelineProvider {
    func placeholder(in context: Context) -> JournalEntry {
        JournalEntry(date: Date(), snapshot: WidgetSnapshot.sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (JournalEntry) -> Void) {
        let snapshot = WidgetSnapshot.read()
        completion(JournalEntry(date: Date(), snapshot: snapshot ?? (context.isPreview ? WidgetSnapshot.sample : nil)))
    }

    /// Now, and again at midnight.
    ///
    /// The app is rarely open at midnight, so the widget turns the day over by
    /// itself: the midnight entry finds the new day missing from the snapshot
    /// and goes back to the prompt.
    func getTimeline(in context: Context, completion: @escaping (Timeline<JournalEntry>) -> Void) {
        let now = Date()
        let snapshot = WidgetSnapshot.read()
        let calendar = Calendar.current
        let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        completion(Timeline(
            entries: [
                JournalEntry(date: now, snapshot: snapshot),
                JournalEntry(date: midnight, snapshot: snapshot),
            ],
            policy: .atEnd
        ))
    }
}

struct JournalWidgetView: View {
    let entry: JournalEntry

    var body: some View {
        Group {
            switch entry.snapshot?.face(on: entry.date) ?? .prompt(nil) {
            case .prompt(let prompt):
                PromptFace(prompt: prompt)
            case .month(let summary):
                MonthFace(summary: summary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(.background, for: .widget)
    }
}

// MARK: - Not written yet today

private struct PromptFace: View {
    let prompt: WidgetPrompt?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(prompt?.theme ?? "goode morming pages")
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 6)

            Text(prompt?.text ?? "open the app once to deal your first prompt.")
                .font(WidgetType.serif(size: 17))
                .lineLimit(6)
                .minimumScaleFactor(0.7)
                .widgetAccentable()

            Spacer(minLength: 6)

            Text("not yet today")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Written today

private struct MonthFace: View {
    let summary: MonthSummary

    private var monthName: String {
        summary.date.formatted(.dateTime.month(.wide))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(monthName).textCase(.uppercase)
                Spacer(minLength: 4)
                Text("done today")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)

            Spacer(minLength: 6)

            MonthGridView(cells: summary.cells)
                .widgetAccentable()

            Spacer(minLength: 6)

            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("\(summary.thisMonth) this month")
                    .foregroundStyle(.tertiary)
                Spacer(minLength: 4)
                Text("\(summary.allTime)")
                    .font(.title3.weight(.bold))
                Text(summary.allTime == 1 ? " day" : " days")
            }
            .font(.caption.weight(.semibold))
            .lineLimit(1)
        }
    }
}

private struct MonthGridView: View {
    let cells: [MonthGrid.Cell]

    /// Seven to a row, the last row padded so every column lines up.
    private var rows: [[MonthGrid.Cell]] {
        stride(from: 0, to: cells.count, by: 7).map { start in
            let row = Array(cells[start..<min(start + 7, cells.count)])
            return row + Array(repeating: MonthGrid.Cell.blank, count: 7 - row.count)
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            ForEach(rows.indices, id: \.self) { row in
                HStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { column in
                        CellView(cell: rows[row][column])
                    }
                }
            }
        }
    }
}

private struct CellView: View {
    let cell: MonthGrid.Cell

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
    }

    var body: some View {
        content
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Tinting flattens every colour to one, so today is told apart by shape:
    /// a ring around its square.
    @ViewBuilder
    private var content: some View {
        switch cell {
        case .blank:
            Color.clear
        case .written:
            shape.fill(Color.primary)
        case .missed:
            shape.fill(Color.primary.opacity(0.12))
        case .ahead:
            shape.strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
        case .today(let written):
            shape
                .fill(written ? Color.primary : Color.primary.opacity(0.12))
                .padding(2.5)
                .overlay(shape.strokeBorder(Color.primary, lineWidth: 1.5))
        }
    }
}

// MARK: - Type

/// The page's own serif, found the same way the editor finds it.
enum WidgetType {
    static func serif(size: CGFloat) -> Font {
        for name in ["EBGaramond-Regular", "EB Garamond", "Iowan Old Style"]
        where NSFont(name: name, size: size) != nil {
            return .custom(name, size: size)
        }
        return .system(size: size, design: .serif)
    }
}

// MARK: - Gallery preview

extension WidgetSnapshot {
    /// What the widget gallery shows before the app has written anything.
    static var sample: WidgetSnapshot {
        WidgetSnapshot(
            prompt: WidgetPrompt(
                text: "what did your mind reach for first when you woke up?",
                theme: "this moment"
            ),
            writtenDays: [],
            updated: Date()
        )
    }
}
