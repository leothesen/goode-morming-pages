import Foundation

/// Counts words the way a writer expects, not the way `split` happens to behave.
///
/// Ensō computes `text.trim().split(/\s+/).length`, which reports **1** for an
/// empty buffer because splitting an empty string yields `[""]`. Starting a
/// session on "1 / 300" is wrong, so this returns 0 for anything blank.
enum WordCount {
    static func count(_ text: String) -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return 0 }
        return trimmed.split(whereSeparator: { $0.isWhitespace }).count
    }
}
