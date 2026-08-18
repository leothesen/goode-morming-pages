import SwiftUI

/// Every emoji the system can render, with its Unicode name for searching.
///
/// This used to be a hand-curated list of about sixty, which meant searching for
/// anything outside it — a gear, a seal, a traffic light — returned "nothing
/// matches" even though the emoji plainly exists. Enumerating the Unicode ranges
/// costs nothing to maintain and gives real name search for free.
enum EmojiCatalog {
    struct Entry: Hashable, Identifiable {
        let emoji: String
        let name: String
        var id: String { emoji }
    }

    /// Blocks that contain emoji. Non-emoji scalars inside them are filtered out
    /// below, so being generous here is safe.
    private static let ranges: [ClosedRange<UInt32>] = [
        0x00A9...0x00AE,    // copyright, registered
        0x203C...0x2049,    // double exclamation, interrobang
        0x2122...0x2139,    // trademark, information
        0x2194...0x21AA,    // arrows
        0x231A...0x231B,    // watch, hourglass
        0x2328...0x2328,    // keyboard
        0x23CF...0x23FA,    // media controls
        0x24C2...0x24C2,    // circled M
        0x25AA...0x25FE,    // geometric shapes
        0x2600...0x27BF,    // miscellaneous symbols and dingbats
        0x2934...0x2935,    // curved arrows
        0x2B00...0x2BFF,    // arrows and stars
        0x3030...0x303D,    // wavy dash, part alternation
        0x3297...0x3299,    // congratulations, secret
        0x1F000...0x1F0FF,  // mahjong, playing cards
        0x1F100...0x1F1E5,  // enclosed alphanumerics, stopping before flags
        0x1F200...0x1F2FF,  // enclosed ideographic
        0x1F300...0x1F5FF,  // symbols and pictographs
        0x1F600...0x1F64F,  // emoticons
        0x1F680...0x1F6FF,  // transport and map
        0x1F780...0x1F7FF,  // geometric extended, coloured shapes
        0x1F900...0x1F9FF,  // supplemental
        0x1FA00...0x1FAFF,  // extended-A
    ]

    static let all: [Entry] = {
        var seen = Set<String>()
        var entries: [Entry] = []

        for range in ranges {
            for value in range {
                guard let scalar = Unicode.Scalar(value) else { continue }
                guard scalar.properties.isEmoji else { continue }
                guard let name = scalar.properties.name else { continue }

                // Filtering on isEmojiPresentation alone silently drops every
                // emoji that defaults to text presentation — the gear, the
                // aeroplane, the red heart. They need a variation selector to
                // render in colour, so add one rather than excluding them.
                let emoji = scalar.properties.isEmojiPresentation
                    ? String(scalar)
                    : String(scalar) + "\u{FE0F}"

                guard seen.insert(emoji).inserted else { continue }
                entries.append(Entry(emoji: emoji, name: name.lowercased()))
            }
        }
        return entries
    }()

    /// Variation selectors make two visually identical emoji compare unequal.
    private static func normalised(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{FE0F}", with: "")
    }

    static func matching(_ query: String) -> [Entry] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return all }

        // Pasting an emoji straight into the field should find it, not just
        // typing its name — with or without a variation selector.
        let pasted = normalised(trimmed)
        if let direct = all.first(where: { normalised($0.emoji) == pasted }) {
            return [direct]
        }
        return all.filter { $0.name.contains(trimmed.lowercased()) }
    }
}

/// A Notion-style icon control: click the icon, get a popover with a searchable
/// grid, plus Random and Remove.
struct EmojiPickerButton: View {
    @Binding var emoji: String
    @State private var isOpen = false
    @State private var query = ""

    private let columns = Array(repeating: GridItem(.fixed(30), spacing: 4), count: 8)

    var body: some View {
        Button {
            isOpen.toggle()
        } label: {
            Group {
                if emoji.isEmpty {
                    Image(systemName: "face.smiling")
                        .font(.system(size: 22))
                        .foregroundStyle(.secondary)
                } else {
                    Text(emoji).font(.system(size: 30))
                }
            }
            .frame(width: 44, height: 44)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(isOpen ? 0.18 : 0.08))
            )
        }
        .buttonStyle(.plain)
        .help("Choose an icon")
        .popover(isPresented: $isOpen, arrowEdge: .bottom) {
            picker
        }
    }

    private var picker: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                TextField("Search", text: $query)
                    .textFieldStyle(.roundedBorder)
                Button("Random") {
                    emoji = EmojiCatalog.all.randomElement()?.emoji ?? emoji
                    isOpen = false
                }
                .font(.caption)
                Button("Remove") {
                    emoji = ""
                    isOpen = false
                }
                .font(.caption)
                .disabled(emoji.isEmpty)
            }

            ScrollView {
                let matches = EmojiCatalog.matching(query)
                if matches.isEmpty {
                    VStack(spacing: 4) {
                        Text("Nothing matches \u{201C}\(query)\u{201D}.")
                        Text("Try a word like \u{201C}coffee\u{201D} or \u{201C}gear\u{201D}.")
                            .foregroundStyle(.tertiary)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 24)
                } else {
                    LazyVGrid(columns: columns, spacing: 4) {
                        ForEach(matches) { entry in
                            Button {
                                emoji = entry.emoji
                                isOpen = false
                            } label: {
                                Text(entry.emoji)
                                    .font(.system(size: 20))
                                    .frame(width: 30, height: 30)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(emoji == entry.emoji
                                                  ? Color.accentColor.opacity(0.3)
                                                  : Color.clear)
                                    )
                            }
                            .buttonStyle(.plain)
                            .help(entry.name)
                        }
                    }
                }
            }
            .frame(height: 220)
        }
        .padding(10)
        .frame(width: 300)
    }
}
