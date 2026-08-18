import SwiftUI
import XCTest
@testable import GoodeMormingPages

/// The bar is the only thing on the blank page, so what it does at zero words
/// matters more than what it does at three hundred.
final class WordGoalTests: XCTestCase {

    func testZeroWordsIsNoProgress() {
        XCTAssertEqual(Metrics.goalFraction(count: 0, goal: 300), 0)
    }

    func testNoGoalHasNoFraction() {
        // Not a division by zero — a goal of 0 means "no target", and a bar
        // drawn for it would be claiming one exists.
        XCTAssertEqual(Metrics.goalFraction(count: 120, goal: 0), 0)
    }

    func testPartwayThrough() {
        XCTAssertEqual(Metrics.goalFraction(count: 150, goal: 300), 0.5, accuracy: 0.0001)
        XCTAssertEqual(Metrics.goalFraction(count: 1, goal: 300), 1.0 / 300, accuracy: 0.0001)
    }

    func testClampsPastTheGoal() {
        // Writing 900 words must not push the fill off the right-hand edge.
        XCTAssertEqual(Metrics.goalFraction(count: 900, goal: 300), 1)
        XCTAssertEqual(Metrics.goalFraction(count: 301, goal: 300), 1)
    }

    func testBedIsVisibleButNotLoud() {
        // If this ever reaches 0 the blank morning goes back to rendering
        // nothing at all, which is the bug this bed exists to fix.
        XCTAssertGreaterThan(Metrics.goalBedOpacity, 0)
        XCTAssertLessThan(Metrics.goalBedOpacity, 0.2)
    }

    func testArrivalIsAcolourChange() {
        // `goalMet` was defined in both palettes and referenced nowhere for a
        // whole release. Naming the decision means it cannot fall out silently
        // again.
        for theme in [Theme.light, Theme.dark] {
            XCTAssertEqual(theme.goalBarColor(hasHitGoal: false), theme.ink)
            XCTAssertEqual(theme.goalBarColor(hasHitGoal: true), theme.goalMet)
            XCTAssertNotEqual(theme.goalMet, theme.ink)
        }
    }

    func testEachGroundHasItsOwnGreen() {
        // One green cannot hold its contrast against both grounds.
        XCTAssertNotEqual(Theme.light.goalMet, Theme.dark.goalMet)
    }

    func testCountIsHiddenUntilTheGoalIsMet() {
        // The bar carries progress; the number only appears on arrival.
        XCTAssertFalse(Metrics.showsWordCount(hasHitGoal: false, goal: 300))
        XCTAssertTrue(Metrics.showsWordCount(hasHitGoal: true, goal: 300))
    }

    func testCountAlwaysShowsWhenThereIsNoGoal() {
        // With no goal the bar has nothing to fill, so the number is all there is.
        XCTAssertTrue(Metrics.showsWordCount(hasHitGoal: false, goal: 0))
        XCTAssertTrue(Metrics.showsWordCount(hasHitGoal: true, goal: 0))
    }

    func testTheSwellIsOneBeat() {
        // Long enough to see, over before it becomes a thing being watched.
        let total = Metrics.goalSwellRise + Metrics.goalSwellFall
        XCTAssertGreaterThan(total, 0.3)
        XCTAssertLessThan(total, 1.0)
        XCTAssertGreaterThan(Metrics.goalSwellScale, 1)
    }
}

/// The toolbar is invisible until hovered, so the size of the region that
/// reveals it is the whole of its discoverability.
final class ToolbarZoneTests: XCTestCase {

    func testTopOfTheWindowShowsTheToolbar() {
        XCTAssertTrue(Metrics.isInToolbarZone(y: 0))
        XCTAssertTrue(Metrics.isInToolbarZone(y: 40))
        XCTAssertTrue(Metrics.isInToolbarZone(y: Metrics.toolbarHoverHeight))
    }

    func testBelowTheStripDoesNot() {
        XCTAssertFalse(Metrics.isInToolbarZone(y: Metrics.toolbarHoverHeight + 1))
        XCTAssertFalse(Metrics.isInToolbarZone(y: 400))
    }

    func testOutsideTheWindowDoesNot() {
        XCTAssertFalse(Metrics.isInToolbarZone(y: -1))
    }

    func testTheStripClearsTheWritingSurface() {
        // The writing block starts 164pt down in the default 680pt window. If
        // the sensing strip ever reached it, the toolbar would light up while
        // you were pointing at your own text.
        let blockTop = (680 - Metrics.windowHeight) / 2 + Metrics.verticalOffset
        XCTAssertLessThan(Metrics.toolbarHoverHeight, blockTop)
    }
}

/// After a sync the screen is cleared and Notion is the only record, so the
/// confirmation is the last thing standing between you and your morning.
final class ToastTests: XCTestCase {

    func testASyncedPageIsOfferedAsALink() {
        let toast = Toast.synced(pageURL: "https://www.notion.so/Morning-abc123")
        XCTAssertNotNil(toast.url)
        XCTAssertEqual(toast.url?.scheme, "https")
        XCTAssertTrue(toast.message.contains("Notion"))
    }

    func testNoPageURLStillConfirms() {
        let toast = Toast.synced(pageURL: nil)
        XCTAssertNil(toast.url)
        XCTAssertEqual(toast.message, "Synced")
    }

    func testAnUnusableURLDegradesRatherThanDangles() {
        // URL(string:) happily builds a relative URL out of a sentence, so
        // without the scheme check this would render as a link to nowhere.
        let toast = Toast.synced(pageURL: "not actually a url")
        XCTAssertNil(toast.url)
        XCTAssertEqual(toast.message, "Synced")

        XCTAssertNil(Toast.synced(pageURL: "").url)
    }

    func testALinkGetsLongerThanAWord() {
        // You have to read it, notice it is a link, and decide to follow it.
        XCTAssertGreaterThan(Toast.synced(pageURL: "https://notion.so/x").seconds,
                             Toast.synced(pageURL: nil).seconds)
        XCTAssertEqual(Toast(message: "Copied").seconds, Toast.plainSeconds)
    }

    @MainActor
    func testFlashShowsAPlainConfirmation() {
        let model = EditorModel(restoring: false)
        model.flash("Copied")
        XCTAssertEqual(model.toast, Toast(message: "Copied"))
        XCTAssertNil(model.toast?.url)
    }

    @MainActor
    func testTheNewestConfirmationWins() {
        let model = EditorModel(restoring: false)
        model.flash("Copied")
        model.show(Toast.synced(pageURL: "https://www.notion.so/x"))
        XCTAssertNotNil(model.toast?.url)
    }
}

/// The app is for the hour before sunrise, which is when macOS is still light.
final class AppearanceTests: XCTestCase {

    func testSystemDefersToTheSystem() {
        XCTAssertNil(Appearance.system.colorScheme)
        XCTAssertEqual(Appearance.system.resolved(system: .dark), .dark)
        XCTAssertEqual(Appearance.system.resolved(system: .light), .light)
    }

    func testAnExplicitChoiceOverridesTheSystem() {
        XCTAssertEqual(Appearance.dark.resolved(system: .light), .dark)
        XCTAssertEqual(Appearance.light.resolved(system: .dark), .light)
        XCTAssertEqual(Appearance.dark.colorScheme, .dark)
        XCTAssertEqual(Appearance.light.colorScheme, .light)
    }

    func testTheEditorDrawsWhatWasAskedFor() {
        XCTAssertEqual(Theme.forScheme(Appearance.dark.resolved(system: .light)).page,
                       Theme.dark.page)
        XCTAssertEqual(Theme.forScheme(Appearance.light.resolved(system: .dark)).page,
                       Theme.light.page)
    }

    func testEveryOptionIsOfferable() {
        XCTAssertEqual(Appearance.allCases.count, 3)
        for option in Appearance.allCases {
            XCTAssertFalse(option.label.isEmpty)
            XCTAssertEqual(option.id, option.rawValue)
        }
    }

    func testThePreferenceSurvivesARelaunch() throws {
        let suite = "AppearanceTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        XCTAssertEqual(Preferences(defaults: defaults).appearance, .system)

        Preferences(defaults: defaults).appearance = .dark
        XCTAssertEqual(Preferences(defaults: defaults).appearance, .dark)
    }

    func testAnUnknownStoredValueFallsBackToTheSystem() throws {
        // Rather than refusing to launch, or picking a side.
        let suite = "AppearanceTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set("sepia", forKey: "appearance")
        XCTAssertEqual(Preferences(defaults: defaults).appearance, .system)
    }
}
