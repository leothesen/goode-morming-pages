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
        VStack(alignment: .leading, spacing: 14) {
            // Laid out like the Notion page it is about to create: icon, then
            // title, then the properties directly underneath.
            HStack(alignment: .center, spacing: 10) {
                EmojiPickerButton(emoji: $emoji)
                VStack(alignment: .leading, spacing: 2) {
                    TextField("Name this session", text: $title)
                        .textFieldStyle(.plain)
                        .font(.system(size: 21, weight: .semibold))
                        .focused($titleFocused)
                        .onSubmit { if canSync { onSync(options) } }
                        .disabled(isSyncing)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }

            if tagProperty != nil { tagRow }
            if let errorMessage { errorRow(errorMessage) }
            Divider()
            footer
        }
        .padding(20)
        .frame(width: 460)
        .onAppear { titleFocused = true }
    }

    private var tagRow: some View {
        HStack(alignment: .top, spacing: 10) {
            Label("Tags", systemImage: "list.bullet")
                .labelStyle(.titleAndIcon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 74, alignment: .leading)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 6) {
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
                    TextField("Add", text: $newTag)
                        .textFieldStyle(.plain)
                        .font(.caption)
                        .frame(width: 70)
                        .onSubmit(addNewTag)
                }
                if allTagOptions.isEmpty {
                    Text("Type a tag and press Return. New tags are created in Notion.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
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
