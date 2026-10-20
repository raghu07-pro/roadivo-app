import XCTest

/// Discover (CarTV's three options: Browser, Cast to Screen, Cast from an app), How to Connect, and Car
/// Mode from the player.
@MainActor
final class CarFlowUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Discover shows only its three options, whether a car is connected or not.
    func testDiscoverShowsTheThreeOptions() throws {
        let app = XCUIApplication.roadivo(skipOnboarding: true)
        app.tabBars.buttons["Discover"].tap()
        XCTAssertTrue(app.buttons["cast.browser"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["cast.mirroring"].exists)
        XCTAssertTrue(app.buttons["cast.fromApp"].exists)
        XCTAssertFalse(app.buttons["cast.guide.link"].exists)
        XCTAssertFalse(app.buttons["car.start"].exists)
        snapshot("18d-Cast-Options", app: app)
        try auditIgnoringBottomEdge(app, for: [.dynamicType, .sufficientElementDescription, .hitRegion])

        let connected = XCUIApplication.roadivo(skipOnboarding: true, carConnected: true)
        connected.tabBars.buttons["Discover"].tap()
        XCTAssertTrue(connected.buttons["cast.browser"].waitForExistence(timeout: 5))
        XCTAssertFalse(connected.descendants(matching: .any)["cast.airplay"].exists)
        XCTAssertFalse(connected.buttons["car.start"].exists)
    }

    /// Cast to Screen: Start Broadcast, the address for the car screen's browser, the steps, and Screen
    /// Mirroring for AirPlay screens. (The broadcast itself needs a real iPhone.)
    func testCastToScreen() throws {
        let app = XCUIApplication.roadivo(skipOnboarding: true)
        app.tabBars.buttons["Discover"].tap()
        let castToScreen = app.buttons["cast.mirroring"]
        XCTAssertTrue(castToScreen.waitForExistence(timeout: 5))
        castToScreen.tap()

        XCTAssertTrue(app.buttons["broadcast.start"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["broadcast.address"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["broadcast.steps"].exists)
        snapshot("47-Cast-To-Screen", app: app)
        try auditIgnoringBottomEdge(app, for: [.dynamicType, .sufficientElementDescription, .hitRegion])

        let mirroring = app.buttons["broadcast.mirroring"]
        app.swipeUp()
        XCTAssertTrue(mirroring.waitForExistence(timeout: 5))
        mirroring.tap()
        XCTAssertTrue(app.descendants(matching: .any)["guide.mirroring"].waitForExistence(timeout: 5))
    }

    /// Cast from an app: the car's screen, the AirPlay steps for other apps, and the user's own videos.
    func testCastFromAnApp() throws {
        let app = XCUIApplication.roadivo(skipOnboarding: true)
        app.tabBars.buttons["Discover"].tap()
        let row = app.buttons["cast.fromApp"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()

        XCTAssertTrue(app.descendants(matching: .any)["castApp.status"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["castApp.steps"].exists)
        XCTAssertTrue(app.buttons["castApp.files"].exists)
        XCTAssertTrue(app.buttons["castApp.photos"].exists)
        snapshot("45-Cast-From-App", app: app)
        try auditIgnoringBottomEdge(app, for: [.dynamicType, .sufficientElementDescription, .hitRegion])
        app.buttons["castApp.photos"].tap()
        // Apple's Photos picker opens over Roadivo, which stays in front.
        XCTAssertEqual(app.state, .runningForeground)
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

    /// How to Connect, from Settings › Media: the steps for each way (no CarPlay steps while CarPlay is
    /// off), Screen Mirroring, Car Mode and the Pro note.
    func testConnectGuideInSettings() throws {
        let app = XCUIApplication.roadivo(skipOnboarding: true)
        app.tabBars.buttons["Settings"].tap()
        let link = app.buttons["settings.connectGuide"]
        XCTAssertTrue(link.waitForExistence(timeout: 5))
        link.tap()

        XCTAssertTrue(app.descendants(matching: .any)["guide.connect"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["guide.airplay"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["guide.carplay"].exists)
        snapshot("18c-Car-Guide", app: app)
        try app.performAccessibilityAudit(for: [.dynamicType, .sufficientElementDescription, .hitRegion])
        app.swipeUp()
        XCTAssertTrue(app.descendants(matching: .any)["guide.mirroring"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["guide.carmode"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["guide.pro"].exists)
    }

    /// In the car the iPhone is locked: the sound plays on in the background. iOS pauses a player still drawing video
    /// when the app leaves the screen, so the mini player lets go of it there (DECISIONS 127).
    func testSoundPlaysOnInTheBackground() {
        let app = XCUIApplication.roadivo(skipOnboarding: true, demoLibrary: true)
        let channel = app.buttons["channel.Football Tonight"]
        XCTAssertTrue(channel.waitForExistence(timeout: 10))
        channel.tap()
        minimizePlayer(app)
        XCTAssertTrue(app.buttons["miniPlayer.pause"].waitForExistence(timeout: 20), "It never started playing")

        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 10))
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        XCTAssertTrue(app.buttons["miniPlayer.pause"].waitForExistence(timeout: 5), "It paused in the background")
        XCTAssertFalse(app.buttons["miniPlayer.play"].exists)
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
        // Apple's AirPlay button sits beside it: video to a car display without mirroring.
        XCTAssertTrue(app.descendants(matching: .any)["player.airplay"].exists)
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
