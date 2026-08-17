import AppKit
import SwiftUI

/// The title prompt. Empty and focused every time, by choice — naming the
/// session is a small deliberate act, not a field to tab past.
///
/// The emoji and tags carry over from last time, because those are habits rather
/// than decisions.
struct SyncSheet: View {
    let wordCount: Int
    let destinationName: String?
    let tagProperty: TagProperty?
    let isSyncing: Bool
    let errorMessage: String?
    let onCancel: () -> Void
    let onSync: (SyncOptions) -> Void

    @State private var title = ""
    @State private var emoji: String
    @State private var selectedTags: Set<String>
    @State private var newTag = ""
    @FocusState private var titleFocused: Bool

    /// A few that suit a morning journal. Any other emoji can be typed or picked
    /// from the system palette.
    private let quickEmoji = ["🌅", "☕️", "📝", "🌱", "🌊", "🧠", "🌙", "✨"]

    init(
        wordCount: Int,
        destinationName: String?,
        tagProperty: TagProperty?,
        initialEmoji: String,
        initialTags: [String],
        isSyncing: Bool,
        errorMessage: String?,
        onCancel: @escaping () -> Void,
        onSync: @escaping (SyncOptions) -> Void
    ) {
        self.wordCount = wordCount
        self.destinationName = destinationName
        self.tagProperty = tagProperty
        self.isSyncing = isSyncing
        self.errorMessage = errorMessage
        self.onCancel = onCancel
        self.onSync = onSync
        _emoji = State(initialValue: initialEmoji)
        _selectedTags = State(initialValue: Set(initialTags))
    }

    private var canSync: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSyncing
    }

    private var options: SyncOptions {
        SyncOptions(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            emoji: emoji.isEmpty ? nil : emoji,
            tags: Array(selectedTags).sorted()
        )
    }

    /// Everything Notion already knows about, plus anything picked this session
    /// that it doesn't.
    private var allTagOptions: [String] {
        let known = tagProperty?.options ?? []
        return (known + selectedTags.filter { !known.contains($0) }).sorted()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            titleRow
            emojiRow
            if tagProperty != nil { tagRow }
            if let errorMessage { errorRow(errorMessage) }
            footer
        }
        .padding(22)
        .frame(width: 440)
        .onAppear { titleFocused = true }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Name this session").font(.headline)
            Text(subtitle).font(.caption).foregroundStyle(.secondary)
        }
    }

    private var titleRow: some View {
        HStack(spacing: 8) {
            Text(emoji.isEmpty ? "  " : emoji).font(.title2)
            TextField("", text: $title)
                .textFieldStyle(.roundedBorder)
                .focused($titleFocused)
                .onSubmit { if canSync { onSync(options) } }
                .disabled(isSyncing)
        }
    }

    private var emojiRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Icon").font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                ForEach(quickEmoji, id: \.self) { option in
                    Button(option) { emoji = option }
                        .buttonStyle(.plain)
                        .padding(4)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(emoji == option ? Color.accentColor.opacity(0.25) : .clear)
                        )
                }
                Button("Other…") { NSApp.orderFrontCharacterPalette(nil) }
                    .buttonStyle(.link)
                    .font(.caption)
                TextField("", text: $emoji)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 46)
                    .onChange(of: emoji) { _, value in
                        // A Notion page icon is exactly one emoji.
                        if let first = value.first, value.count > 1 {
                            emoji = String(first)
                        }
                    }
            }
        }
    }

    private var tagRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Tags").font(.caption).foregroundStyle(.secondary)
            FlowLayout(spacing: 6) {
                ForEach(allTagOptions, id: \.self) { tag in
                    let isOn = selectedTags.contains(tag)
                    Button(tag) { toggle(tag) }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(isOn ? Color.accentColor.opacity(0.25) : Color.secondary.opacity(0.12))
                        )
                        .overlay(
                            Capsule().stroke(isOn ? Color.accentColor : .clear, lineWidth: 1)
                        )
                }
            }
            HStack(spacing: 6) {
                TextField("Add a tag", text: $newTag)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addNewTag)
                Button("Add", action: addNewTag)
                    .disabled(newTag.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            Text("New tags are created in Notion on sync.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func errorRow(_ message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.red)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var footer: some View {
        HStack {
            if isSyncing {
                ProgressView().controlSize(.small)
                Text("Sending…").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Cancel", action: onCancel)
                .keyboardShortcut(.cancelAction)
                .disabled(isSyncing)
            Button("Sync") { onSync(options) }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSync)
        }
    }

    private func toggle(_ tag: String) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            // A single-select column can only hold one.
            if tagProperty?.allowsMultiple == false { selectedTags.removeAll() }
            selectedTags.insert(tag)
        }
    }

    private func addNewTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if tagProperty?.allowsMultiple == false { selectedTags.removeAll() }
        selectedTags.insert(trimmed)
        newTag = ""
    }

    private var subtitle: String {
        let words = wordCount == 1 ? "1 word" : "\(wordCount) words"
        if let destinationName { return "\(words) → \(destinationName)" }
        return words
    }
}

/// What the sheet hands back.
struct SyncOptions {
    let title: String
    let emoji: String?
    let tags: [String]
}

/// Wraps chips onto as many rows as they need.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 400
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
