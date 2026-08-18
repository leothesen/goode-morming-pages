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

    /// The toolbar is shown by the pointer being in the top strip, or on the
    /// buttons themselves. Both are tracked, because a child view can take the
    /// hover away from its parent — and a toolbar that vanishes as you reach for
    /// it is worse than one that never appeared.
    @State private var pointerNearTop = false
    @State private var pointerOnToolbar = false

    /// Set while typing, cleared by the next pointer movement.
    @State private var chromeDismissed = false

    @State private var isActive = false
    @State private var showSyncSheet = false
    @State private var activityTask: Task<Void, Never>?

    /// Resolved here rather than read back out of the environment after
    /// `preferredColorScheme`, so the scrims and the caret can never be a frame
    /// behind the ground they have to match exactly.
    private var theme: Theme {
        Theme.forScheme(preferences.appearance.resolved(system: scheme))
    }

    private var toolbarVisible: Bool {
        (pointerNearTop || pointerOnToolbar) && !chromeDismissed
    }

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
            .onHover { pointerOnToolbar = $0 }
        }
        .overlay(alignment: .bottom) {
            WordGoalBar(
                count: model.wordCount,
                goal: preferences.wordGoal,
                hasHitGoal: model.hasHitGoal,
                theme: theme
            )
        }
        .overlay(alignment: .bottomTrailing) {
            // Only once you've arrived — or always, when there is no goal and
            // the bar has nothing to fill.
            if Metrics.showsWordCount(
                hasHitGoal: model.hasHitGoal,
                goal: preferences.wordGoal
            ) {
                WordCountView(
                    count: model.wordCount,
                    hasHitGoal: model.hasHitGoal,
                    isActive: isActive,
                    theme: theme
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 14)
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.5), value: model.hasHitGoal)
        .overlay(alignment: .bottom) {
            if let toast = model.toast {
                ToastView(toast: toast, theme: theme)
                    .padding(.bottom, 16)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.3), value: model.toast)
        .onContinuousHover(coordinateSpace: .local) { phase in
            switch phase {
            case .active(let point):
                // Any movement means you are reaching for something, so it
                // also undoes the dismissal that typing caused.
                chromeDismissed = false
                pointerNearTop = Metrics.isInToolbarZone(y: point.y)
            case .ended:
                pointerNearTop = false
            }
        }
        .onChange(of: model.text) { _, _ in
            model.textDidChange(goal: preferences.wordGoal)
            markActive()
        }
        .task {
            // Tag options live in Notion and change there. Pulling the schema on
            // launch means you never have to revisit Settings to see a new tag.
            await preferences.refreshSchema()
        }
        .onChange(of: showSyncSheet) { _, isShowing in
            if isShowing { Task { await preferences.refreshSchema() } }
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
                tagProperty: preferences.tagProperty,
                initialEmoji: preferences.lastEmoji,
                initialTags: preferences.defaultTags,
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
    ///
    /// Typing also puts the toolbar away. The hover strip is wide enough that
    /// the pointer is often parked inside it by accident, and chrome sitting lit
    /// above the page for a whole session is worse than chrome you have to go
    /// and find. Moving the pointer brings it straight back.
    private func markActive() {
        chromeDismissed = true
        isActive = true
        activityTask?.cancel()
        activityTask = Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            if !Task.isCancelled { isActive = false }
        }
    }

    private func performSync(options: SyncOptions) {
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
            titleKey: titleKey,
            tagProperty: preferences.tagProperty
        )
        let text = model.text
        model.isSyncing = true
        model.errorMessage = nil

        Task { @MainActor in
            do {
                let page = try await service.sync(
                    text: text,
                    title: options.title,
                    icon: options.emoji,
                    tags: options.tags
                )
                // Habits, not decisions — offer the same choices next time.
                if let emoji = options.emoji { preferences.lastEmoji = emoji }
                if !options.tags.isEmpty { preferences.defaultTags = options.tags }

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
