import SwiftUI

@main
struct GoodeMormingPagesApp: App {
    @StateObject private var preferences = Preferences.shared

    var body: some Scene {
        Window("Goode Morming Pages", id: "editor") {
            EditorView(preferences: preferences)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 960, height: 680)
        .commands {
            // Nothing here opens a document, saves a file, or prints. Replacing
            // these groups is how the app stays as small as it claims to be.
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .saveItem) {}
            CommandGroup(replacing: .printItem) {}

            CommandMenu("Session") {
                Button("Sync to Notion…") {
                    NotificationCenter.default.post(name: .requestSync, object: nil)
                }
                .keyboardShortcut("s", modifiers: .command)

                Button("Copy Everything") {
                    NotificationCenter.default.post(name: .requestCopy, object: nil)
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView(preferences: preferences)
        }
    }
}
