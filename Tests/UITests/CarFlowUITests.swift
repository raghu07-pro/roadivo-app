import XCTest

/// Discover (Browser and Cast to Screen; DECISIONS 135) and Car Mode from the player.
@MainActor
final class CarFlowUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Discover shows only its two options, whether a car is connected or not; Cast from an app is gone.
    func testDiscoverShowsTheTwoOptions() throws {
        let app = XCUIApplication.playcartv(skipOnboarding: true)
        app.tabBars.buttons["Discover"].tap()
        XCTAssertTrue(app.buttons["cast.browser"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["cast.mirroring"].exists)
        XCTAssertFalse(app.buttons["cast.fromApp"].exists)
        XCTAssertFalse(app.buttons["cast.guide.link"].exists)
        XCTAssertFalse(app.buttons["car.start"].exists)
        snapshot("18d-Cast-Options", app: app)
        try auditIgnoringBottomEdge(app, for: [.dynamicType, .sufficientElementDescription, .hitRegion])

        let connected = XCUIApplication.playcartv(skipOnboarding: true, carConnected: true)
        connected.tabBars.buttons["Discover"].tap()
        XCTAssertTrue(connected.buttons["cast.browser"].waitForExistence(timeout: 5))
        XCTAssertFalse(connected.descendants(matching: .any)["cast.airplay"].exists)
        XCTAssertFalse(connected.buttons["car.start"].exists)
    }

    /// Cast to Screen, as simple as CarTV's: where the iPhone is, and one button, Start mirroring. (The broadcast
    /// itself needs a real iPhone.)
    func testCastToScreen() throws {
        let app = XCUIApplication.playcartv(skipOnboarding: true, carConnected: true)
        app.tabBars.buttons["Discover"].tap()
        let castToScreen = app.buttons["cast.mirroring"]
        XCTAssertTrue(castToScreen.waitForExistence(timeout: 5))
        castToScreen.tap()

        XCTAssertTrue(app.buttons["cast.start"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["cast.status"].exists)
        XCTAssertFalse(app.buttons["cast.end"].exists)
        snapshot("47-Cast-To-Screen", app: app)
        try auditIgnoringBottomEdge(app, for: [.dynamicType, .sufficientElementDescription, .hitRegion])
    }

    /// While the iPhone broadcasts, the one button becomes End mirroring.
    func testCastToScreenWhileMirroring() throws {
        let app = XCUIApplication.playcartv(skipOnboarding: true, carConnected: true, broadcasting: true)
        app.tabBars.buttons["Discover"].tap()
        let castToScreen = app.buttons["cast.mirroring"]
        XCTAssertTrue(castToScreen.waitForExistence(timeout: 5))
        castToScreen.tap()

        XCTAssertTrue(app.buttons["cast.end"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["cast.start"].exists)
        snapshot("47b-Cast-To-Screen-Mirroring", app: app)
        try auditIgnoringBottomEdge(app, for: [.dynamicType, .sufficientElementDescription, .hitRegion])
    }

    /// Drive View hides the video and keeps three big buttons, is remembered when Car Mode opens again,
    /// and Exit Drive View brings the video back.
    func testDriveViewHidesTheVideoAndComesBack() throws {
        // The player's car button is gone (DECISIONS 155); Car Mode opens only from a car's display profile for now.
        try XCTSkipIf(true, "Car Mode has no button in the player; its look is covered by ScreenSnapshotTests")
        let app = XCUIApplication.playcartv(skipOnboarding: true, demoLibrary: true, pro: true, carConnected: true)
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

    /// A film that ends counts down to the next over the player, where Play Now and Cancel keep their own names and
    /// pass the audit (UI tests count from 120).
    func testUpNextWhenAFilmEnds() throws {
        let app = XCUIApplication.playcartv(skipOnboarding: true, demoLibrary: true, pro: true)
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

        app.buttons["upNext.cancel"].tap()
        XCTAssertTrue(card.waitForNonExistence(timeout: 5))
    }

    /// In the car the iPhone is locked: the sound plays on in the background. iOS pauses a player still drawing video
    /// when the app leaves the screen, so the mini player lets go of it there (DECISIONS 127).
    func testSoundPlaysOnInTheBackground() {
        let app = XCUIApplication.playcartv(skipOnboarding: true, demoLibrary: true)
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
}
