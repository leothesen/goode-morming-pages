import Sparkle
import SwiftUI

/// Sparkle needs a real app lifecycle hook, which the SwiftUI `App` protocol
/// doesn't provide, so the updater is started from an AppDelegate.
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// `startingUpdater: false` so nothing touches the network until the app has
    /// actually finished launching.
    static let updaterController = SPUStandardUpdaterController(
        startingUpdater: false,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.updaterController.startUpdater()
    }

    /// One window, and closing it means you're done for the morning.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@main
struct GoodeMormingPagesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
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

            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    AppDelegate.updaterController.checkForUpdates(nil)
                }
            }

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
