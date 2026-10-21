import XCTest

/// Discover (Browser and Cast to Screen; DECISIONS 135), How to Connect, and Car Mode from the player.
@MainActor
final class CarFlowUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Discover shows only its two options, whether a car is connected or not; Cast from an app is gone.
    func testDiscoverShowsTheTwoOptions() throws {
        let app = XCUIApplication.roadivo(skipOnboarding: true)
        app.tabBars.buttons["Discover"].tap()
        XCTAssertTrue(app.buttons["cast.browser"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["cast.mirroring"].exists)
        XCTAssertFalse(app.buttons["cast.fromApp"].exists)
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

    /// Cast to Screen: Start Broadcast, the address for the car screen's browser, the steps behind the ?, and
    /// Screen Mirroring for AirPlay screens. (The broadcast itself needs a real iPhone.)
    func testCastToScreen() throws {
        let app = XCUIApplication.roadivo(skipOnboarding: true)
        app.tabBars.buttons["Discover"].tap()
        let castToScreen = app.buttons["cast.mirroring"]
        XCTAssertTrue(castToScreen.waitForExistence(timeout: 5))
        castToScreen.tap()

        XCTAssertTrue(app.buttons["broadcast.start"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["broadcast.address"].exists)
        snapshot("47-Cast-To-Screen", app: app)
        try auditIgnoringBottomEdge(app, for: [.dynamicType, .sufficientElementDescription, .hitRegion])
        try checkStepsHelp(app, identifier: "broadcast", snapshot: "47c-Cast-To-Screen-Steps")

        let mirroring = app.buttons["broadcast.mirroring"]
        app.swipeUp()
        XCTAssertTrue(mirroring.waitForExistence(timeout: 5))
        mirroring.tap()
        XCTAssertTrue(app.descendants(matching: .any)["guide.mirroring"].waitForExistence(timeout: 5))
    }

    /// Local Network off: the car's screen can't reach the iPhone, so Cast to Screen says so and Open Settings
    /// goes straight to Roadivo's settings.
    func testCastToScreenAsksForLocalNetwork() throws {
        let app = XCUIApplication.roadivo(skipOnboarding: true, localNetworkDenied: true)
        app.tabBars.buttons["Discover"].tap()
        let castToScreen = app.buttons["cast.mirroring"]
        XCTAssertTrue(castToScreen.waitForExistence(timeout: 5))
        castToScreen.tap()

        XCTAssertTrue(app.descendants(matching: .any)["broadcast.localNetwork"].waitForExistence(timeout: 5))
        let openSettings = app.buttons["broadcast.openSettings"]
        XCTAssertTrue(openSettings.isHittable)
        snapshot("47b-Cast-To-Screen-Local-Network", app: app)
        try auditIgnoringBottomEdge(app, for: [.dynamicType, .sufficientElementDescription, .hitRegion])

        openSettings.tap()
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        XCTAssertTrue(settings.wait(for: .runningForeground, timeout: 10), "Open Settings didn't open Settings")
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

    /// How to Connect, from Settings › Media: the CarPlay steps first (CarPlay Audio is granted and on,
    /// DECISIONS 127), then AirPlay, Screen Mirroring, Car Mode and the Pro note.
    func testConnectGuideInSettings() throws {
        let app = XCUIApplication.roadivo(skipOnboarding: true)
        app.tabBars.buttons["Settings"].tap()
        let link = app.buttons["settings.connectGuide"]
        XCTAssertTrue(link.waitForExistence(timeout: 5))
        link.tap()

        XCTAssertTrue(app.descendants(matching: .any)["guide.carplay"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["guide.airplay"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["guide.connect"].exists)
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
