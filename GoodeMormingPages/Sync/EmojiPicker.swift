import SwiftUI

/// The emoji offered in the picker, with keywords so search finds them.
///
/// A curated set rather than the whole Unicode table: this is a journal, and a
/// grid you can scan beats one you have to search. Anything not here can still
/// be pasted into the search field directly.
enum EmojiCatalog {
    struct Entry: Hashable {
        let emoji: String
        let keywords: String
    }

    static let all: [Entry] = [
        .init(emoji: "🌅", keywords: "sunrise morning dawn"),
        .init(emoji: "🌄", keywords: "sunrise mountain morning"),
        .init(emoji: "☀️", keywords: "sun day bright"),
        .init(emoji: "🌤", keywords: "sun cloud weather"),
        .init(emoji: "🌊", keywords: "wave sea ocean surf"),
        .init(emoji: "🌙", keywords: "moon night late"),
        .init(emoji: "⭐️", keywords: "star night"),
        .init(emoji: "✨", keywords: "sparkles magic good"),
        .init(emoji: "🔥", keywords: "fire hot streak"),
        .init(emoji: "🌱", keywords: "seedling growth new start"),
        .init(emoji: "🌳", keywords: "tree nature calm"),
        .init(emoji: "🍂", keywords: "leaves autumn fall"),
        .init(emoji: "☕️", keywords: "coffee morning cup"),
        .init(emoji: "🍵", keywords: "tea calm cup"),
        .init(emoji: "📝", keywords: "memo write note pencil"),
        .init(emoji: "✍️", keywords: "writing hand pen"),
        .init(emoji: "📖", keywords: "book open read"),
        .init(emoji: "📓", keywords: "notebook journal"),
        .init(emoji: "📔", keywords: "notebook journal decorated"),
        .init(emoji: "🖋", keywords: "pen fountain ink"),
        .init(emoji: "🗒", keywords: "notepad list"),
        .init(emoji: "🧠", keywords: "brain think mind"),
        .init(emoji: "💭", keywords: "thought bubble thinking"),
        .init(emoji: "💡", keywords: "idea lightbulb insight"),
        .init(emoji: "🎯", keywords: "target goal focus"),
        .init(emoji: "🧩", keywords: "puzzle piece problem"),
        .init(emoji: "🪞", keywords: "mirror reflection self"),
        .init(emoji: "🧘", keywords: "meditation calm zen"),
        .init(emoji: "❤️", keywords: "heart love"),
        .init(emoji: "💔", keywords: "broken heart sad hurt"),
        .init(emoji: "🙏", keywords: "gratitude thanks pray"),
        .init(emoji: "😀", keywords: "happy smile good"),
        .init(emoji: "🙂", keywords: "slight smile fine ok"),
        .init(emoji: "😐", keywords: "neutral flat meh"),
        .init(emoji: "😔", keywords: "sad down low"),
        .init(emoji: "😤", keywords: "frustrated angry steam"),
        .init(emoji: "😴", keywords: "sleep tired rest"),
        .init(emoji: "🤯", keywords: "mind blown overwhelmed"),
        .init(emoji: "🥲", keywords: "bittersweet tears smile"),
        .init(emoji: "🫥", keywords: "invisible absent numb"),
        .init(emoji: "🏃", keywords: "running exercise move"),
        .init(emoji: "🚶", keywords: "walking slow think"),
        .init(emoji: "🏔", keywords: "mountain climb hard"),
        .init(emoji: "🧭", keywords: "compass direction plan"),
        .init(emoji: "⚓️", keywords: "anchor steady ground"),
        .init(emoji: "🔑", keywords: "key unlock answer"),
        .init(emoji: "🪟", keywords: "window clarity view"),
        .init(emoji: "🕯", keywords: "candle quiet still"),
        .init(emoji: "📅", keywords: "calendar date day"),
        .init(emoji: "⏳", keywords: "hourglass time waiting"),
        .init(emoji: "🎧", keywords: "headphones music listen"),
        .init(emoji: "🎸", keywords: "guitar music play"),
        .init(emoji: "🏡", keywords: "home house family"),
        .init(emoji: "✈️", keywords: "plane travel away"),
        .init(emoji: "💼", keywords: "work briefcase job"),
        .init(emoji: "💰", keywords: "money finance"),
        .init(emoji: "🩺", keywords: "health doctor body"),
        .init(emoji: "🌧", keywords: "rain grey weather"),
        .init(emoji: "❄️", keywords: "snow cold winter"),
        .init(emoji: "🦭", keywords: "seal animal sea"),
    ]

    static func matching(_ query: String) -> [Entry] {
        let trimmed = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty else { return all }
        return all.filter {
            $0.keywords.contains(trimmed) || $0.emoji.contains(trimmed)
        }
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
                    Text("Nothing matches “\(query)”.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 20)
                } else {
                    LazyVGrid(columns: columns, spacing: 4) {
                        ForEach(matches, id: \.self) { entry in
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
                            .help(entry.keywords)
                        }
                    }
                }
            }
            .frame(height: 190)
        }
        .padding(10)
        .frame(width: 300)
    }
}
