import SwiftUI

/// Progress toward the day's goal, as a hairline across the foot of the window.
///
/// A number you can read is a number you can do arithmetic against, and doing
/// arithmetic about how much is left is the opposite of writing. A line that
/// reaches the right-hand edge says the same thing without inviting the sum.
///
/// The bed behind the fill earns its place: without it the bar has no width at
/// zero words, so the blank morning draws nothing at all and there is no way to
/// tell a goal from no goal. The bed is the distance; the fill is how much of it
/// you have covered.
struct WordGoalBar: View {
    let count: Int
    let goal: Int
    let hasHitGoal: Bool
    let theme: Theme

    /// Held for one beat as the goal is crossed, then released.
    @State private var swelling = false

    private var fraction: Double {
        Metrics.goalFraction(count: count, goal: goal)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(theme.ink)
                    .opacity(Metrics.goalBedOpacity)

                Rectangle()
                    .fill(theme.goalBarColor(hasHitGoal: hasHitGoal))
                    .frame(width: proxy.size.width * fraction)
                    // Anchored to the bottom edge, so the swell grows up into
                    // the page and costs nothing in layout.
                    .scaleEffect(
                        y: swelling ? Metrics.goalSwellScale : 1,
                        anchor: .bottom
                    )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: Metrics.goalBarHeight)
        // A goal of zero is not a goal, and a bed with nothing behind it would
        // imply one.
        .opacity(goal > 0 ? 1 : 0)
        .animation(.easeOut(duration: 0.45), value: fraction)
        .animation(.easeOut(duration: 0.4), value: hasHitGoal)
        .allowsHitTesting(false)
        .accessibilityElement()
        .accessibilityHidden(goal == 0)
        .accessibilityLabel("Word goal")
        .accessibilityValue("\(count) of \(goal) words")
        .onChange(of: hasHitGoal) { _, hit in markArrival(hit) }
    }

    /// A colour that simply *is* different reads as configuration. A colour that
    /// *becomes* different reads as an event, and the whole difference is about
    /// half a second.
    ///
    /// One beat and no more. Confetti belongs in a different kind of app.
    private func markArrival(_ hit: Bool) {
        guard hit else {
            swelling = false
            return
        }
        withAnimation(.easeOut(duration: Metrics.goalSwellRise)) { swelling = true }
        Task { @MainActor in
            try? await Task.sleep(
                nanoseconds: UInt64(Metrics.goalSwellRise * 1_000_000_000)
            )
            withAnimation(.easeInOut(duration: Metrics.goalSwellFall)) {
                swelling = false
            }
        }
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
                .help("Token, destination, appearance and daily goal")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.glass)
        }
        .opacity(isVisible ? 1 : 0)
        .blur(radius: isVisible ? 0 : 4)
        .offset(y: isVisible ? 0 : -12)
        // Faded out it is still a live target, and clicking a control you cannot
        // see is never what anyone meant to do.
        .allowsHitTesting(isVisible)
        .accessibilityHidden(!isVisible)
        .animation(.easeOut(duration: 0.45), value: isVisible)
    }
}

/// Brief confirmation, at the foot of the window where the other status already
/// lives. Named for what happened, never an apology.
///
/// It carries a URL when there is somewhere worth going — which in practice
/// means the Notion page a sync just created, and which is the one moment in
/// this app where leaving it is the right thing to do.
struct ToastView: View {
    let toast: Toast
    let theme: Theme

    var body: some View {
        Group {
            if let url = toast.url {
                Link(destination: url) {
                    HStack(spacing: 5) {
                        Text(toast.message)
                        Image(systemName: "arrow.up.forward")
                            .font(.system(size: 9, weight: .semibold))
                    }
                }
                .buttonStyle(.plain)
                .pointerStyle(.link)
            } else {
                Text(toast.message)
            }
        }
        .font(.system(size: 12))
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(theme.ink, in: Capsule())
        .foregroundStyle(theme.page)
    }
}
