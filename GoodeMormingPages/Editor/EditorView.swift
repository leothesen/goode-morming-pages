import SwiftUI

extension Notification.Name {
    static let requestSync = Notification.Name("co.leothesen.gmp.requestSync")
    static let requestCopy = Notification.Name("co.leothesen.gmp.requestCopy")
}

struct EditorView: View {
    @ObservedObject var preferences: Preferences
    @StateObject private var model = EditorModel()

    @Environment(\.colorScheme) private var scheme
    @Environment(\.openSettings) private var openSettings

    @State private var toolbarVisible = false
    @State private var isActive = false
    @State private var showSyncSheet = false
    @State private var activityTask: Task<Void, Never>?

    private var theme: Theme { Theme.forScheme(scheme) }

    var body: some View {
        ZStack {
            // Flat and opaque, always. The scrims erase by matching this exactly.
            theme.page.ignoresSafeArea()

            ZStack(alignment: .top) {
                ScrimTextView(
                    text: $model.text,
                    theme: theme,
                    spelling: preferences.spelling
                )
                ScrimOverlay(theme: theme)
            }
            .frame(width: Metrics.measure, height: Metrics.windowHeight)
            .offset(y: Metrics.verticalOffset)
        }
        .overlay(alignment: .top) {
            EditorToolbar(
                isVisible: toolbarVisible,
                canSync: !model.text.isEmpty && !model.isSyncing,
                onSync: { showSyncSheet = true },
                onCopy: { model.copyAll() },
                onSettings: { openSettings() }
            )
            .padding(.top, 16)
            .onHover { toolbarVisible = $0 }
        }
        .overlay(alignment: .bottomTrailing) {
            WordCountView(
                count: model.wordCount,
                goal: preferences.wordGoal,
                hasHitGoal: model.hasHitGoal,
                isActive: isActive,
                theme: theme
            )
            .padding(20)
        }
        .overlay(alignment: .top) {
            if let toast = model.toast {
                ToastView(message: toast, theme: theme)
                    .padding(.top, 16)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.3), value: model.toast)
        .onChange(of: model.text) { _, _ in
            model.textDidChange(goal: preferences.wordGoal)
            markActive()
        }
        .onReceive(NotificationCenter.default.publisher(for: .requestSync)) { _ in
            if !model.text.isEmpty { showSyncSheet = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: .requestCopy)) { _ in
            model.copyAll()
        }
        .sheet(isPresented: $showSyncSheet) {
            SyncSheet(
                wordCount: model.wordCount,
                destinationName: preferences.dataSourceName,
                isSyncing: model.isSyncing,
                errorMessage: model.errorMessage,
                onCancel: {
                    showSyncSheet = false
                    model.errorMessage = nil
                },
                onSync: performSync
            )
        }
    }

    /// The count lifts from 20% to 50% while you are writing, then settles back.
    private func markActive() {
        isActive = true
        activityTask?.cancel()
        activityTask = Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            if !Task.isCancelled { isActive = false }
        }
    }

    private func performSync(title: String) {
        guard let token = Keychain.notionToken,
              let destinationID = preferences.dataSourceID,
              let titleKey = preferences.titlePropertyKey
        else {
            model.errorMessage = NotionError.notConfigured.localizedDescription
            return
        }

        let service = SyncService(
            client: NotionClient(token: token),
            destinationID: destinationID,
            titleKey: titleKey
        )
        let text = model.text
        model.isSyncing = true
        model.errorMessage = nil

        Task { @MainActor in
            do {
                let page = try await service.sync(text: text, title: title)
                // Only now is it safe to clear: Notion is the only record.
                model.isSyncing = false
                showSyncSheet = false
                model.clearAfterSync(pageURL: page.url)
            } catch {
                model.isSyncing = false
                model.errorMessage = error.localizedDescription
            }
        }
    }
}
