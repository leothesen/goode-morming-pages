import AppKit
import Combine
import Foundation

@MainActor
final class EditorModel: ObservableObject {
    @Published var text: String = ""

    /// Latched. Crossing the goal is the event worth marking; dropping back
    /// under it by deleting a word is not, so the green stays for the session.
    @Published private(set) var hasHitGoal = false

    @Published var isSyncing = false
    @Published var errorMessage: String?
    @Published var lastSyncedURL: String?
    @Published var toast: String?

    private var autosave: AnyCancellable?
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
    func clearAfterSync(pageURL: String?) {
        text = ""
        hasHitGoal = false
        lastSyncedURL = pageURL
        BufferStore.clear()
        flash("Synced")
    }

    func flash(_ message: String) {
        toast = message
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if toast == message { toast = nil }
        }
    }
}
