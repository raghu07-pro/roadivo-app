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

    /// Drive View hides the video and keeps three big buttons, is remembered when Car Mode opens again,
    /// and Exit Drive View brings the video back.
    func testDriveViewHidesTheVideoAndComesBack() throws {
        let app = XCUIApplication.roadivo(skipOnboarding: true, demoLibrary: true, pro: true, carConnected: true)
        let channel = app.buttons["channel.Steel Horizon · 1080p"]
        XCTAssertTrue(channel.waitForExistence(timeout: 10))
        channel.tap()
        revealPlayerControls(app)
        app.buttons["player.carMode"].tap()

        let driveView = app.buttons["carMode.driveView"]
        let video = app.descendants(matching: .any)["carMode.video"]
        XCTAssertTrue(driveView.waitForExistence(timeout: 5))
        XCTAssertTrue(video.exists)
        driveView.tap()
        XCTAssertTrue(app.buttons["carMode.exitDriveView"].waitForExistence(timeout: 5))
        XCTAssertFalse(video.exists)

        // Left in Drive View, Car Mode opens in it again.
        app.buttons["carMode.exit"].tap()
        revealPlayerControls(app)
        app.buttons["player.carMode"].tap()
        XCTAssertTrue(app.buttons["carMode.exitDriveView"].waitForExistence(timeout: 5))
        for control in ["carMode.drive.previous", "carMode.drive.playPause", "carMode.drive.next", "carMode.exit"] {
            XCTAssertTrue(app.buttons[control].exists, control)
        }
        // No screenshot: XCUITest captures Car Mode's forced landscape sideways. `ScreenSnapshotTests` draws it.
        XCTAssertFalse(driveView.exists)
        try auditIgnoringBottomEdge(app, for: [.dynamicType, .sufficientElementDescription, .hitRegion])

        app.buttons["carMode.exitDriveView"].tap()
        XCTAssertTrue(driveView.waitForExistence(timeout: 5))
        XCTAssertTrue(video.exists)
        XCTAssertFalse(app.buttons["carMode.drive.playPause"].exists)
    }

    /// A film that ends counts down to the next over the player, then over Car Mode's video and in Drive
    /// View, where Play Now and Cancel keep their own names and pass the audit (UI tests count from 120).
    func testUpNextWhenAFilmEnds() throws {
        let app = XCUIApplication.roadivo(skipOnboarding: true, demoLibrary: true, pro: true)
        let film = app.buttons["channel.Steel Horizon · 1080p"]
        XCTAssertTrue(film.waitForExistence(timeout: 10))
        film.tap()
        revealPlayerControls(app)
        let scrubber = app.sliders["player.scrubber"]
        XCTAssertTrue(scrubber.waitForExistence(timeout: 20))
        scrubber.adjust(toNormalizedSliderPosition: 0.998)

        let card = app.descendants(matching: .any)["upNext.countdown"]
        XCTAssertTrue(card.waitForExistence(timeout: 30))
        XCTAssertTrue(app.buttons["upNext.playNow"].isHittable)
        XCTAssertTrue(app.buttons["upNext.cancel"].isHittable)
        // "SH": the playing film's cover initials in the grid, art drawn to fit its tile and hidden from
        // VoiceOver (the card reads its title); the audit still sees the text and enlarges it in place.
        try auditIgnoringBottomEdge(
            app,
            for: [.dynamicType, .sufficientElementDescription, .hitRegion],
            alsoIgnoring: ["SH"]
        )

        revealPlayerControls(app)
        app.buttons["player.carMode"].tap()
        XCTAssertTrue(app.buttons["upNext.playNow"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["upNext.playNow"].isHittable)
        // "Drive View": Car Mode's button trades its label for the steering wheel when larger text won't
        // fit beside the other buttons (`ViewThatFits`); the audit enlarges the label in place instead.
        try auditIgnoringBottomEdge(
            app,
            for: [.dynamicType, .sufficientElementDescription, .hitRegion],
            alsoIgnoring: ["Drive View"]
        )

        app.buttons["carMode.driveView"].tap()
        let cancel = app.buttons["upNext.cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        XCTAssertTrue(cancel.isHittable)
        try auditIgnoringBottomEdge(app, for: [.dynamicType, .sufficientElementDescription, .hitRegion])
        cancel.tap()
        XCTAssertTrue(card.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["carMode.drive.playPause"].exists)
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

    /// How to Connect opens from the Car tab's link before a car connects, and from the top bar once one
    /// has, with the steps for each way (no CarPlay steps while CarPlay is off) and the Pro note.
    func testConnectGuideOpensFromTheCarTab() throws {
        let app = XCUIApplication.roadivo(skipOnboarding: true)
        app.tabBars.buttons["Cast to Car"].tap()
        let link = app.buttons["cast.guide.link"]
        XCTAssertTrue(link.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["cast.guide"].exists) // The link is on the page, so no top-bar button.
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

        let connected = XCUIApplication.roadivo(skipOnboarding: true, carConnected: true)
        connected.tabBars.buttons["Cast to Car"].tap()
        let help = connected.buttons["cast.guide"]
        XCTAssertTrue(help.waitForExistence(timeout: 5))
        help.tap()
        XCTAssertTrue(connected.descendants(matching: .any)["guide.connect"].waitForExistence(timeout: 5))
    }

    /// The player's car button opens Car Mode without a car connected (how App Review reaches it).
    func testPlayerOpensCarModeForPro() {
        let app = XCUIApplication.roadivo(skipOnboarding: true, demoLibrary: true, pro: true)
        let channel = app.buttons["channel.Highway Stop"]
        XCTAssertTrue(channel.waitForExistence(timeout: 10))
        channel.tap()
        let carMode = app.buttons["player.carMode"]
        XCTAssertTrue(carMode.waitForExistence(timeout: 5))
        revealPlayerControls(app)
        carMode.tap()
        XCTAssertTrue(app.buttons["carMode.exit"].waitForExistence(timeout: 5))
    }

    /// A free user sees the Car Mode plans over the player, and closing them leaves the video playing.
    func testPlayerCarModeAsksFreeUsersForPro() {
        let app = XCUIApplication.roadivo(skipOnboarding: true, demoLibrary: true)
        let channel = app.buttons["channel.Highway Stop"]
        XCTAssertTrue(channel.waitForExistence(timeout: 10))
        channel.tap()
        let carMode = app.buttons["player.carMode"]
        XCTAssertTrue(carMode.waitForExistence(timeout: 5))
        revealPlayerControls(app)
        carMode.tap()
        let close = app.buttons["paywall.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        close.tap()
        XCTAssertFalse(app.buttons["carMode.exit"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["player.video"].waitForExistence(timeout: 5))
    }

    /// Buying from the player's Car Mode button goes straight on into Car Mode.
    func testBuyingFromThePlayerOpensCarMode() {
        let app = XCUIApplication.roadivo(skipOnboarding: true, demoLibrary: true)
        let channel = app.buttons["channel.Highway Stop"]
        XCTAssertTrue(channel.waitForExistence(timeout: 10))
        channel.tap()
        let carMode = app.buttons["player.carMode"]
        XCTAssertTrue(carMode.waitForExistence(timeout: 5))
        revealPlayerControls(app)
        carMode.tap()
        let buy = app.buttons["paywall.buy"]
        XCTAssertTrue(buy.waitForExistence(timeout: 5))
        buy.tap()
        XCTAssertTrue(app.buttons["carMode.exit"].waitForExistence(timeout: 10))
    }
}
