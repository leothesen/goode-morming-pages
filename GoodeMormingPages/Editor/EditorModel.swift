import AppKit
import Combine
import Foundation

/// A confirmation, and optionally somewhere to go because of it.
struct Toast: Equatable {
    let message: String
    var url: URL?

    /// Long enough to read, notice it is a link, and decide to follow it.
    static let linkedSeconds: Double = 6
    static let plainSeconds: Double = 2

    /// How long this one should stay up. Somewhere to go takes longer to act on
    /// than something to read.
    var seconds: Double { url == nil ? Self.plainSeconds : Self.linkedSeconds }

    /// The confirmation for a completed sync.
    ///
    /// `URL(string:)` succeeds on plenty of things that are not addresses --
    /// it will happily build a relative URL out of a sentence -- so a missing
    /// scheme degrades to a plain confirmation rather than offering a link that
    /// goes nowhere.
    static func synced(pageURL: String?) -> Toast {
        guard let pageURL,
              let url = URL(string: pageURL),
              url.scheme != nil
        else { return Toast(message: "Synced") }

        return Toast(message: "Synced \u{00B7} open in Notion", url: url)
    }
}

@MainActor
final class EditorModel: ObservableObject {
    @Published var text: String = ""

    /// Latched. Crossing the goal is the event worth marking; dropping back
    /// under it by deleting a word is not, so the green stays for the session.
    @Published private(set) var hasHitGoal = false

    @Published var isSyncing = false
    @Published var errorMessage: String?
    @Published var toast: Toast?

    private var autosave: AnyCancellable?
    private var toastTask: Task<Void, Never>?
    private let textChanged = PassthroughSubject<String, Never>()

    init(restoring: Bool = true) {
        if restoring { text = BufferStore.load() }

        // Autosave is debounced: it protects against a crash, it is not a
        // per-keystroke journal.
        autosave = textChanged
            .debounce(for: .milliseconds(400), scheduler: DispatchQueue.main)
            .sink { BufferStore.save($0) }
    }

    var wordCount: Int { WordCount.count(text) }

    func textDidChange(goal: Int) {
        textChanged.send(text)
        if goal > 0, wordCount >= goal { hasHitGoal = true }
    }

    func copyAll() {
        guard !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        flash("Copied")
    }

    /// Called only after Notion confirms the page and every batch landed.
    ///
    /// The screen is about to be the only thing that ever held this session, and
    /// then it won't hold it either. The confirmation carries the way back.
    func clearAfterSync(pageURL: String?) {
        text = ""
        hasHitGoal = false
        BufferStore.clear()

        show(Toast.synced(pageURL: pageURL))
    }

    func flash(_ message: String) {
        show(Toast(message: message))
    }

    func show(_ toast: Toast) {
        toastTask?.cancel()
        self.toast = toast
        toastTask = Task { @MainActor in
            try? await Task.sleep(
                nanoseconds: UInt64(toast.seconds * 1_000_000_000)
            )
            guard !Task.isCancelled else { return }
            self.toast = nil
        }
    }
}
