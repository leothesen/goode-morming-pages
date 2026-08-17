import Foundation

enum RuntimeEnvironment {
    /// True when the app is running as an XCTest host.
    ///
    /// The test host is the real app, so anything it does on launch happens
    /// during every test run. Two things must not: a modal alert, which blocks
    /// the run loop until the runner gives up connecting, and a network call,
    /// which makes the suite flaky for reasons that have nothing to do with the
    /// code under test.
    static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || NSClassFromString("XCTestCase") != nil
    }
}
