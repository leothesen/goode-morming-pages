import Foundation

/// Turns a writing session into Notion paragraph blocks, respecting the API's
/// two hard caps.
///
/// Both caps bite on ordinary input, not pathological input: morning pages are
/// exactly the style that produces one enormous unbroken paragraph.
enum BlockBuilder {
    /// Maximum characters in a single rich-text object.
    static let maxCharacters = 2_000

    /// Maximum elements in any block array, including `children` on page create.
    static let maxBlocksPerRequest = 100

    /// Splits text into paragraph blocks, breaking any paragraph that exceeds
    /// the rich-text cap at a word boundary where possible.
    static func blocks(from text: String) -> [[String: Any]] {
        paragraphs(in: text)
            .flatMap { split($0) }
            .map(paragraph)
    }

    /// Groups consecutive non-blank lines into one block each.
    ///
    /// A single newline stays *inside* the block as a line break, because Notion
    /// renders a newline in rich text as a soft break. Only a blank line starts
    /// a new block.
    ///
    /// Turning every newline into its own block — which is what this used to do —
    /// produces a visibly empty paragraph between each line in Notion, since
    /// blocks carry their own vertical spacing on top of the break you wanted.
    static func paragraphs(in text: String) -> [String] {
        var groups: [String] = []
        var current: [String] = []

        for line in text.components(separatedBy: .newlines) {
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                if !current.isEmpty {
                    groups.append(current.joined(separator: "\n"))
                    current = []
                }
            } else {
                current.append(line)
            }
        }
        if !current.isEmpty { groups.append(current.joined(separator: "\n")) }

        return groups
    }

    /// Breaks one paragraph into pieces of at most `maxCharacters`.
    ///
    /// Prefers the last whitespace inside the window. A run of `maxCharacters`
    /// with no whitespace in it — a pasted URL, or someone holding a key down —
    /// is cut at the limit rather than being allowed through oversized.
    static func split(_ paragraph: String, limit: Int = maxCharacters) -> [String] {
        guard paragraph.count > limit else { return [paragraph] }

        var pieces: [String] = []
        var remainder = Substring(paragraph)

        while remainder.count > limit {
            let windowEnd = remainder.index(remainder.startIndex, offsetBy: limit)
            let window = remainder[remainder.startIndex..<windowEnd]

            let cut: Substring.Index
            if let lastSpace = window.lastIndex(where: { $0.isWhitespace }) {
                cut = lastSpace
            } else {
                cut = windowEnd
            }

            let piece = remainder[remainder.startIndex..<cut]
            pieces.append(String(piece))

            // Step over the whitespace we broke on, if that is what we cut at.
            var next = cut
            if cut != windowEnd, next < remainder.endIndex {
                next = remainder.index(after: next)
            }
            remainder = remainder[next...]
        }

        if !remainder.isEmpty { pieces.append(String(remainder)) }
        return pieces
    }

    /// Groups blocks into request-sized batches.
    static func batches(_ blocks: [[String: Any]], size: Int = maxBlocksPerRequest) -> [[[String: Any]]] {
        guard !blocks.isEmpty else { return [] }
        return stride(from: 0, to: blocks.count, by: size).map {
            Array(blocks[$0..<min($0 + size, blocks.count)])
        }
    }

    static func paragraph(_ content: String) -> [String: Any] {
        [
            "object": "block",
            "type": "paragraph",
            "paragraph": [
                "rich_text": content.isEmpty
                    ? []
                    : [["type": "text", "text": ["content": content]]],
            ],
        ]
    }
}
