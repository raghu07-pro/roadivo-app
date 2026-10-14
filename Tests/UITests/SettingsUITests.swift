import XCTest

@MainActor
final class SettingsUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Media lists only Manage Sources; adding a source lives on Home and in
    /// Manage Sources.
    func testMediaHasOnlyManageSources() {
        let app = XCUIApplication.roadivo(skipOnboarding: true)
        app.tabBars.buttons.element(boundBy: 3).tap()
        XCTAssertTrue(app.buttons["settings.sources"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["settings.addSource"].exists)
    }

    /// Share Roadivo opens the system share sheet.
    func testShareOpensTheShareSheet() {
        let app = XCUIApplication.roadivo(skipOnboarding: true)
        app.tabBars.buttons.element(boundBy: 3).tap()
        XCTAssertTrue(app.buttons["settings.theme"].waitForExistence(timeout: 5))
        // About is below the fold, and a List only builds rows on screen.
        app.swipeUp()
        let share = app.descendants(matching: .any)["settings.share"].firstMatch
        XCTAssertTrue(share.waitForExistence(timeout: 5))
        share.tap()
        XCTAssertTrue(app.otherElements["ActivityListView"].waitForExistence(timeout: 5), "No share sheet")
        snapshot("30-Share", app: app)
    }

    /// Rate Roadivo is offered and enabled. Not tapped: without an App Store
    /// ID it shows the system review prompt, which the test can't dismiss
    /// reliably.
    func testRateIsOffered() {
        let app = XCUIApplication.roadivo(skipOnboarding: true)
        app.tabBars.buttons.element(boundBy: 3).tap()
        XCTAssertTrue(app.buttons["settings.theme"].waitForExistence(timeout: 5))
        app.swipeUp()
        let rate = app.buttons["settings.rate"]
        XCTAssertTrue(rate.waitForExistence(timeout: 5))
        XCTAssertTrue(rate.isEnabled)
    }

    /// Touch and hold a card: the menu opens over a larger preview. The
    /// screenshot is for checking the lift; Delete (red) is in Sources' menu.
    func testLongPressShowsPreviewAndMenu() {
        let app = XCUIApplication.roadivo(skipOnboarding: true, demoLibrary: true)
        let card = app.buttons["channel.Football Tonight"]
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        card.press(forDuration: 1.2)
        XCTAssertTrue(app.buttons["Play"].waitForExistence(timeout: 5))
        snapshot("31-Card-Menu", app: app)
        app.tap()

        app.tabBars.buttons.element(boundBy: 3).tap()
        app.buttons["settings.sources"].tap()
        let row = app.descendants(matching: .any)["source.Road Trip"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.press(forDuration: 1.2)
        XCTAssertTrue(app.buttons["Delete"].waitForExistence(timeout: 5))
        snapshot("32-Source-Menu", app: app)
    }
}
