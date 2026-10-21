import XCTest

@MainActor
final class SettingsUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Media lists Manage Sources and How to Connect; adding a source lives on Home and in
    /// Manage Sources.
    func testMediaHasSourcesAndHowToConnect() {
        let app = XCUIApplication.roadivo(skipOnboarding: true)
        app.tabBars.buttons.element(boundBy: 4).tap()
        XCTAssertTrue(app.buttons["settings.sources"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["settings.connectGuide"].exists)
        XCTAssertFalse(app.buttons["settings.addSource"].exists)
    }

    /// How to Connect is in Settings too, to find again after setup or to help someone; Back
    /// returns to Settings.
    func testHowToConnectOpensFromSettings() {
        let app = XCUIApplication.roadivo(skipOnboarding: true)
        app.tabBars.buttons.element(boundBy: 4).tap()
        let row = app.buttons["settings.connectGuide"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(app.descendants(matching: .any)["guide.carplay"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["guide.airplay"].exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(row.waitForExistence(timeout: 5))
    }

    /// Share Roadivo opens the system share sheet.
    func testShareOpensTheShareSheet() {
        let app = XCUIApplication.roadivo(skipOnboarding: true)
        app.tabBars.buttons.element(boundBy: 4).tap()
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
    /// Rate is always offered (the system prompt until the App Store ID exists); not tapped, as the
    /// prompt is the system's.
    func testRateIsOffered() {
        let app = XCUIApplication.roadivo(skipOnboarding: true)
        app.tabBars.buttons.element(boundBy: 4).tap()
        XCTAssertTrue(app.buttons["settings.theme"].waitForExistence(timeout: 5))
        app.swipeUp()
        let rate = app.buttons["settings.rate"]
        XCTAssertTrue(rate.waitForExistence(timeout: 5))
        XCTAssertTrue(rate.isEnabled)
    }

    /// Pro users can reach their subscription; it isn't tapped, as the App Store sheet is the system's.
    func testProOffersManageSubscription() {
        let app = XCUIApplication.roadivo(skipOnboarding: true, pro: true)
        app.tabBars.buttons.element(boundBy: 4).tap()
        let manage = app.buttons["settings.manageSubscription"]
        XCTAssertTrue(manage.waitForExistence(timeout: 5))
        XCTAssertTrue(manage.isEnabled)
    }

    /// Free users have nothing to manage; the Pro banner offers the upgrade instead.
    func testFreeUsersHaveNoManageSubscription() {
        let app = XCUIApplication.roadivo(skipOnboarding: true)
        app.tabBars.buttons.element(boundBy: 4).tap()
        XCTAssertTrue(app.buttons["settings.pro"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["settings.manageSubscription"].exists)
    }

    /// Help & FAQ ends with Contact Support; not tapped, as Mail opens outside the app.
    func testHelpOffersContactSupport() {
        let app = XCUIApplication.roadivo(skipOnboarding: true)
        app.tabBars.buttons.element(boundBy: 4).tap()
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
    /// Favorites only lists favourites: its menu removes from Favorites, and has no Delete.
    func testFavoritesMenuHasNoDelete() {
        let app = XCUIApplication.roadivo(skipOnboarding: true, demoLibrary: true)
        let card = app.buttons["channel.Football Tonight"]
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        card.press(forDuration: 1.2)
        let add = app.buttons["Add to Favorites"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        app.tabBars.buttons.element(boundBy: 1).tap()
        let favorite = app.buttons["channel.Football Tonight"]
        XCTAssertTrue(favorite.waitForExistence(timeout: 5))
        favorite.press(forDuration: 1.2)
        XCTAssertTrue(app.buttons["Remove from Favorites"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Delete"].exists)
    }

    func testLongPressShowsPreviewAndMenu() {
        let app = XCUIApplication.roadivo(skipOnboarding: true, demoLibrary: true)
        let card = app.buttons["channel.Football Tonight"]
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        card.press(forDuration: 1.2)
        XCTAssertTrue(app.buttons["Play"].waitForExistence(timeout: 5))
        snapshot("31-Card-Menu", app: app)
        app.tap()

        app.tabBars.buttons.element(boundBy: 4).tap()
        app.buttons["settings.sources"].tap()
        let row = app.descendants(matching: .any)["source.Road Trip"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.press(forDuration: 1.2)
        XCTAssertTrue(app.buttons["Delete"].waitForExistence(timeout: 5))
        snapshot("32-Source-Menu", app: app)
    }
}
