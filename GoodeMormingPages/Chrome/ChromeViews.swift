import SwiftUI

/// Progress toward the day's goal, as a hairline across the foot of the window.
///
/// A number you can read is a number you can do arithmetic against, and doing
/// arithmetic about how much is left is the opposite of writing. A line that
/// reaches the right-hand edge says the same thing without inviting the sum.
///
/// The count itself only appears once you have arrived, when it stops being a
/// target and becomes a fact.
struct WordGoalBar: View {
    let count: Int
    let goal: Int
    let theme: Theme

    /// Clamped, so writing past the goal doesn't overflow the window.
    private var fraction: Double {
        guard goal > 0 else { return 0 }
        return min(Double(count) / Double(goal), 1)
    }

    var body: some View {
        GeometryReader { proxy in
            Rectangle()
                .fill(theme.ink)
                .frame(width: proxy.size.width * fraction, height: 2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 2)
        .animation(.easeOut(duration: 0.45), value: fraction)
        .allowsHitTesting(false)
    }
}

/// The word count, shown only once the goal is met — or always, if there is no
/// goal set, since then the bar has nothing to fill.
struct WordCountView: View {
    let count: Int
    let hasHitGoal: Bool
    let isActive: Bool
    let theme: Theme

    var body: some View {
        Text(count == 1 ? "1 word" : "\(count) words")
            .font(.system(size: 13))
            .monospacedDigit()
            .foregroundStyle(theme.ink)
            .opacity(hasHitGoal ? 0.55 : (isActive ? 0.5 : 0.2))
            .animation(.easeOut(duration: 0.4), value: isActive)
            .animation(.easeOut(duration: 0.4), value: hasHitGoal)
    }
}

/// Sync, Copy and Settings. Chrome in the truest sense: gone until wanted.
///
/// Liquid Glass belongs here — it floats above the page and disappears. The
/// three buttons share a `GlassEffectContainer` so they read as one control
/// rather than three separate blobs.
struct EditorToolbar: View {
    let isVisible: Bool
    let canSync: Bool
    let onSync: () -> Void
    let onCopy: () -> Void
    let onSettings: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: 14) {
            HStack(spacing: 14) {
                Button(action: onSync) {
                    Label("Sync", systemImage: "arrow.up.to.line")
                }
                .disabled(!canSync)
                .help("Send this session to Notion")

                Button(action: onCopy) {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .help("Copy the whole session to the clipboard")

                Button(action: onSettings) {
                    Label("Settings", systemImage: "gearshape")
                }
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.glass)
        }
        .opacity(isVisible ? 1 : 0)
        .blur(radius: isVisible ? 0 : 4)
        .offset(y: isVisible ? 0 : -12)
        .animation(.easeOut(duration: 0.45), value: isVisible)
    }
}

/// Brief confirmation. Named for what happened, never an apology.
struct ToastView: View {
    let message: String
    let theme: Theme

    var body: some View {
        Text(message)
            .font(.system(size: 12))
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(theme.ink, in: Capsule())
            .foregroundStyle(theme.page)
    }
}
