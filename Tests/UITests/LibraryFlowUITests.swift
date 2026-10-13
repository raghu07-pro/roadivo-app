import XCTest

@MainActor
final class LibraryFlowUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testPlayMinimizeAndCarMode() {
        let app = XCUIApplication.roadivo(skipOnboarding: true, demoLibrary: true, pro: true)
        let channel = app.buttons["channel.Football Tonight"]
        XCTAssertTrue(channel.waitForExistence(timeout: 10))
        channel.tap()

        let minimize = app.buttons["player.minimize"]
        XCTAssertTrue(minimize.waitForExistence(timeout: 5))
        app.buttons["player.carMode"].tap()

        let exit = app.buttons["carMode.exit"]
        XCTAssertTrue(exit.waitForExistence(timeout: 5))
        exit.tap()

        XCTAssertTrue(minimize.waitForExistence(timeout: 5))
        minimize.tap()

        let miniPlayer = app.buttons["miniPlayer.expand"]
        XCTAssertTrue(miniPlayer.waitForExistence(timeout: 5))
        app.buttons["miniPlayer.close"].tap()
        XCTAssertFalse(miniPlayer.waitForExistence(timeout: 2))
    }

    func testSearchFiltersHome() {
        let app = XCUIApplication.roadivo(skipOnboarding: true, demoLibrary: true)
        XCTAssertTrue(app.buttons["channel.Football Tonight"].waitForExistence(timeout: 10))
        let search = app.searchFields.firstMatch
        search.tap()
        search.typeText("coastal")
        XCTAssertTrue(app.buttons["channel.Coastal Echoes"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["channel.Football Tonight"].exists)
    }

    func testAddSourceRejectsABadLink() {
        let app = XCUIApplication.roadivo(skipOnboarding: true)
        let add = app.buttons["library.empty.addSource"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        let link = app.textFields["addSource.link"]
        XCTAssertTrue(link.waitForExistence(timeout: 5))
        link.tap()
        link.typeText("not a link")
        XCTAssertFalse(app.buttons["addSource.submit"].isEnabled)
        XCTAssertTrue(app.staticTexts["No usable link found"].waitForExistence(timeout: 2))
    }

    func testCarTabStartsCarModeForTheLastPlayed() {
        let app = XCUIApplication.roadivo(skipOnboarding: true, demoLibrary: true, pro: true)
        let channel = app.buttons["channel.Highway Stop"]
        XCTAssertTrue(channel.waitForExistence(timeout: 10))
        channel.tap()
        let minimize = app.buttons["player.minimize"]
        XCTAssertTrue(minimize.waitForExistence(timeout: 5))
        minimize.tap()
        app.tabBars.buttons["Cast to Car"].tap()
        let start = app.buttons["car.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()
        XCTAssertTrue(app.buttons["carMode.exit"].waitForExistence(timeout: 5))
    }

    func testCarModeAsksFreeUsersForPro() {
        let app = XCUIApplication.roadivo(skipOnboarding: true, demoLibrary: true)
        let channel = app.buttons["channel.Football Tonight"]
        XCTAssertTrue(channel.waitForExistence(timeout: 10))
        channel.tap()
        // Tapping while the player is still animating in can be dropped.
        let carMode = app.buttons["player.carMode"]
        XCTAssertTrue(carMode.waitForExistence(timeout: 5))
        carMode.tap()
        let close = app.buttons["paywall.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        close.tap()
        XCTAssertTrue(app.buttons["player.minimize"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["carMode.exit"].exists)
    }

    func testSecondSourceAsksFreeUsersForPro() {
        let app = XCUIApplication.roadivo(skipOnboarding: true, demoLibrary: true)
        XCTAssertTrue(app.buttons["channel.Football Tonight"].waitForExistence(timeout: 10))
        app.buttons["library.addSource"].tap()
        XCTAssertTrue(app.buttons["paywall.close"].waitForExistence(timeout: 5))
    }

    func testMediaServerLoginIsReachable() {
        let app = XCUIApplication.roadivo(skipOnboarding: true)
        app.buttons["library.empty.addSource"].tap()
        let jellyfin = app.buttons["addSource.server.jellyfin"]
        XCTAssertTrue(jellyfin.waitForExistence(timeout: 5))
        jellyfin.tap()
        XCTAssertTrue(app.textFields["server.address"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["server.connect"].isEnabled)
    }

    func testHomeAccessibilityAudit() throws {
        let app = XCUIApplication.roadivo(skipOnboarding: true, demoLibrary: true)
        XCTAssertTrue(app.buttons["channel.Football Tonight"].waitForExistence(timeout: 10))
        try app.performAccessibilityAudit(for: [.dynamicType, .sufficientElementDescription, .hitRegion])
    }
}
