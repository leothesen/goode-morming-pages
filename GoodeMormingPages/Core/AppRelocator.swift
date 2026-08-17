import AppKit

/// Offers to move the app into /Applications on launch, then relaunches from there.
///
/// Without this you end up running the app out of ~/Downloads, and a second
/// download leaves you with "GoodeMormingPages 2.app" sitting beside the first.
/// macOS then disambiguates the duplicates by filename, so the app appears to
/// have renamed itself.
enum AppRelocator {
    private static let applications = "/Applications"


    /// True when the running bundle is somewhere it shouldn't live permanently.
    static func shouldOfferMove(bundlePath: String = Bundle.main.bundlePath) -> Bool {
        // A modal alert in the test host blocks the run loop, and the test runner
        // then hangs before it can connect — which reads as an unrelated failure.
        if RuntimeEnvironment.isRunningTests { return false }
        // Never nag during development.
        if bundlePath.contains("/DerivedData/") { return false }
        if bundlePath.contains("/.claude/") { return false }
        if bundlePath.hasPrefix(applications) { return false }
        if bundlePath.hasPrefix(NSHomeDirectory() + applications) { return false }
        return true
    }

    @MainActor
    static func offerMoveIfNeeded(preferences: Preferences) {
        guard !preferences.declinedRelocation, shouldOfferMove() else { return }

        let alert = NSAlert()
        alert.messageText = "Move to Applications?"
        alert.informativeText = """
            Goode Morming Pages is running from \(Bundle.main.bundleURL.deletingLastPathComponent().path).

            Moving it to your Applications folder keeps updates tidy — otherwise \
            every download leaves another copy behind.
            """
        alert.addButton(withTitle: "Move to Applications")
        alert.addButton(withTitle: "Not Now")
        alert.alertStyle = .informational

        guard alert.runModal() == .alertFirstButtonReturn else {
            preferences.declinedRelocation = true
            return
        }

        do {
            let destination = try move()
            relaunch(at: destination)
        } catch {
            let failure = NSAlert()
            failure.messageText = "Couldn't move the app"
            failure.informativeText = """
                \(error.localizedDescription)

                Drag it into Applications yourself and reopen it from there.
                """
            failure.runModal()
        }
    }

    /// Copies the bundle to /Applications, replacing any existing copy, and
    /// trashes the original.
    static func move() throws -> URL {
        let source = Bundle.main.bundleURL
        let destination = URL(fileURLWithPath: applications)
            .appendingPathComponent(source.lastPathComponent)
        let manager = FileManager.default

        if manager.fileExists(atPath: destination.path) {
            _ = try manager.replaceItemAt(destination, withItemAt: source)
            return destination
        }

        // Copy rather than move: the bundle is currently executing, and the
        // original is only discarded once the copy is safely in place.
        try manager.copyItem(at: source, to: destination)
        try? manager.trashItem(at: source, resultingItemURL: nil)
        return destination
    }

    /// Launches the relocated copy and quits this one.
    private static func relaunch(at url: URL) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true

        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }
}
