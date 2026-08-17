import SwiftUI

/// The title prompt. Empty and focused every time, by choice — naming the
/// session is a small deliberate act, not a field to tab past.
struct SyncSheet: View {
    let wordCount: Int
    let destinationName: String?
    let isSyncing: Bool
    let errorMessage: String?
    let onCancel: () -> Void
    let onSync: (String) -> Void

    @State private var title = ""
    @FocusState private var titleFocused: Bool

    private var canSync: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSyncing
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Name this session")
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            TextField("", text: $title)
                .textFieldStyle(.roundedBorder)
                .focused($titleFocused)
                .onSubmit { if canSync { onSync(title) } }
                .disabled(isSyncing)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                if isSyncing {
                    ProgressView().controlSize(.small)
                    Text("Sending…").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                    .disabled(isSyncing)
                Button("Sync") { onSync(title) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSync)
            }
        }
        .padding(22)
        .frame(width: 380)
        .onAppear { titleFocused = true }
    }

    private var subtitle: String {
        let words = wordCount == 1 ? "1 word" : "\(wordCount) words"
        if let destinationName { return "\(words) → \(destinationName)" }
        return words
    }
}
