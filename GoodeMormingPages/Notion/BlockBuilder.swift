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
    ///
    /// Blank lines are preserved as empty paragraphs so the page keeps the shape
    /// you wrote it in.
    static func blocks(from text: String) -> [[String: Any]] {
        text
            .components(separatedBy: .newlines)
            .flatMap { split($0) }
            .map(paragraph)
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

    private static func paragraph(_ content: String) -> [String: Any] {
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
