import SwiftUI

/// The word count, and the only feedback the app ever gives you.
///
/// Plain text on purpose. This sits over the writing canvas, and a glass capsule
/// around a number in the corner of an empty page is noise wearing a material.
struct WordCountView: View {
    let count: Int
    let goal: Int
    let hasHitGoal: Bool
    let isActive: Bool
    let theme: Theme

    var body: some View {
        Text(goal > 0 ? "\(count) / \(goal)" : "\(count)")
            .font(.system(size: 13))
            .monospacedDigit()
            .foregroundStyle(hasHitGoal ? theme.goalMet : theme.ink)
            .opacity(hasHitGoal ? 1 : (isActive ? 0.5 : 0.2))
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
