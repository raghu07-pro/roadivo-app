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

    /// UI tests run without an App Store ID, so there's no review page and Rate Roadivo is hidden.
    func testRateIsHiddenWithoutAppStoreID() {
        let app = XCUIApplication.roadivo(skipOnboarding: true)
        app.tabBars.buttons.element(boundBy: 3).tap()
        XCTAssertTrue(app.buttons["settings.theme"].waitForExistence(timeout: 5))
        app.swipeUp()
        // Share is in the same section, so once it's built Rate would be too.
        XCTAssertTrue(app.descendants(matching: .any)["settings.share"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["settings.rate"].exists)
    }

    /// Pro users can reach their subscription; it isn't tapped, as the App Store sheet is the system's.
    func testProOffersManageSubscription() {
        let app = XCUIApplication.roadivo(skipOnboarding: true, pro: true)
        app.tabBars.buttons.element(boundBy: 3).tap()
        let manage = app.buttons["settings.manageSubscription"]
        XCTAssertTrue(manage.waitForExistence(timeout: 5))
        XCTAssertTrue(manage.isEnabled)
    }

    /// Free users have nothing to manage; the Pro banner offers the upgrade instead.
    func testFreeUsersHaveNoManageSubscription() {
        let app = XCUIApplication.roadivo(skipOnboarding: true)
        app.tabBars.buttons.element(boundBy: 3).tap()
        XCTAssertTrue(app.buttons["settings.pro"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["settings.manageSubscription"].exists)
    }

    /// Help & FAQ ends with Contact Support; not tapped, as Mail opens outside the app.
    func testHelpOffersContactSupport() {
        let app = XCUIApplication.roadivo(skipOnboarding: true)
        app.tabBars.buttons.element(boundBy: 3).tap()
        XCTAssertTrue(app.buttons["settings.theme"].waitForExistence(timeout: 5))
        app.swipeUp()
        let help = app.buttons["settings.help"]
        XCTAssertTrue(help.waitForExistence(timeout: 5))
        help.tap()
        let contact = app.buttons["help.contactSupport"]
        for _ in 0..<4 where !(contact.exists && contact.isHittable) {
            app.swipeUp()
        }
        XCTAssertTrue(contact.waitForExistence(timeout: 5))
        XCTAssertTrue(contact.isHittable)
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
