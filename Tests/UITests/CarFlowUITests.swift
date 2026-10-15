import XCTest

/// Cast to Car: before and after a car is connected, Car Mode, AirPlay and How to Connect.
@MainActor
final class CarFlowUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Before a car is connected the tab only explains how to connect: no Car Mode or AirPlay buttons.
    func testCarTabWaitsForACar() {
        let app = XCUIApplication.roadivo(skipOnboarding: true, demoLibrary: true, pro: true)
        XCTAssertTrue(app.buttons["channel.Highway Stop"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Cast to Car"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["cast.status"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["car.start"].exists)
        XCTAssertFalse(app.buttons["car.browse"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["cast.airplay"].exists)
    }

    /// Connected, the AirPlay card holds Apple's own AirPlay button, which lists the screens (the list
    /// itself needs a real iPhone).
    func testAirPlayButtonIsTheSystemPicker() {
        let app = XCUIApplication.roadivo(skipOnboarding: true, carConnected: true)
        app.tabBars.buttons["Cast to Car"].tap()
        let picker = app.descendants(matching: .any)["cast.airplay"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        XCTAssertTrue(picker.isHittable)
        XCTAssertGreaterThanOrEqual(picker.frame.width, 44)
    }

    func testCarTabStartsCarModeForTheLastPlayed() {
        let app = XCUIApplication.roadivo(skipOnboarding: true, demoLibrary: true, pro: true, carConnected: true)
        let channel = app.buttons["channel.Highway Stop"]
        XCTAssertTrue(channel.waitForExistence(timeout: 10))
        channel.tap()
        let minimize = app.buttons["player.minimize"]
        XCTAssertTrue(minimize.waitForExistence(timeout: 5))
        minimize.tap()
        app.tabBars.buttons["Cast to Car"].tap()
        let start = app.buttons["car.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        snapshot("18b-Car-Connected", app: app)
        app.swipeUp() // On smaller iPhones the button starts behind the mini player.
        start.tap()
        XCTAssertTrue(app.buttons["carMode.exit"].waitForExistence(timeout: 5))
    }

    func testCarModeAsksFreeUsersForPro() {
        let app = XCUIApplication.roadivo(skipOnboarding: true, demoLibrary: true, carConnected: true)
        let channel = app.buttons["channel.Football Tonight"]
        XCTAssertTrue(channel.waitForExistence(timeout: 10))
        channel.tap()
        let minimize = app.buttons["player.minimize"]
        XCTAssertTrue(minimize.waitForExistence(timeout: 5))
        minimize.tap()
        app.tabBars.buttons["Cast to Car"].tap()
        let start = app.buttons["car.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        app.swipeUp() // On smaller iPhones the button starts behind the mini player.
        start.tap()
        let close = app.buttons["paywall.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        close.tap()
        XCTAssertFalse(app.buttons["carMode.exit"].exists)
    }

    /// How to Connect opens from the Car tab, both from the link and the top bar, with the steps for
    /// each way to the car (no CarPlay steps while CarPlay is off) and the Pro note for free users.
    func testConnectGuideOpensFromTheCarTab() throws {
        let app = XCUIApplication.roadivo(skipOnboarding: true)
        app.tabBars.buttons["Cast to Car"].tap()
        let link = app.buttons["cast.guide.link"]
        XCTAssertTrue(link.waitForExistence(timeout: 5))
        link.tap()

        let connect = app.descendants(matching: .any)["guide.connect"]
        XCTAssertTrue(connect.waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["guide.airplay"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["guide.carplay"].exists)
        snapshot("18c-Car-Guide", app: app)
        try app.performAccessibilityAudit(for: [.dynamicType, .sufficientElementDescription, .hitRegion])
        app.swipeUp()
        XCTAssertTrue(app.descendants(matching: .any)["guide.carmode"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["guide.pro"].exists)

        app.navigationBars.buttons.element(boundBy: 0).tap()
        let help = app.buttons["cast.guide"]
        XCTAssertTrue(help.waitForExistence(timeout: 5))
        help.tap()
        XCTAssertTrue(connect.waitForExistence(timeout: 5))
    }
}
