import XCTest

extension XCUIApplication {
    /// Launches with in-memory storage and a fake App Store so every UI test
    /// starts clean. `skipOnboarding` also skips the intro paywall.
    /// `restorable`: a Yearly plan bought earlier, which only Restore brings back.
    /// `carConnected`: the iPhone acts as if plugged into a car (CarPlay audio).
    static func roadivo(
        skipOnboarding: Bool = false,
        demoLibrary: Bool = false,
        pro: Bool = false,
        restorable: Bool = false,
        carConnected: Bool = false
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        if skipOnboarding {
            app.launchArguments.append("-skip-onboarding")
        }
        if demoLibrary {
            app.launchArguments.append("-demo-library")
        }
        if pro {
            app.launchArguments.append("-pro")
        }
        if restorable {
            app.launchArguments.append("-restorable")
        }
        if carConnected {
            app.launchArguments.append("-car-connected")
        }
        app.launch()
        return app
    }
}

extension XCTestCase {
    /// Waits until `element` is fully on screen and has stopped moving, so a
    /// screenshot never catches a page mid-swipe.
    func waitUntilSettled(_ element: XCUIElement, in app: XCUIApplication, timeout: TimeInterval = 5) {
        let screen = app.windows.firstMatch.frame
        let deadline = Date().addingTimeInterval(timeout)
        var last = CGRect.null
        while Date() < deadline {
            let frame = element.exists ? element.frame : .null
            if !frame.isNull, screen.contains(frame), frame == last {
                return
            }
            last = frame
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        XCTFail("\(element) did not settle on screen")
    }

    /// Runs `types`, ignoring only Dynamic Type findings on text within 180 pt of the tab bar or screen
    /// bottom: the audit enlarges text in place, and what slides out of view reads as "partially unsupported".
    func auditIgnoringBottomEdge(_ app: XCUIApplication, for types: XCUIAccessibilityAuditType) throws {
        let tabBar = app.tabBars.firstMatch
        let edge = tabBar.exists ? tabBar.frame.minY : app.windows.firstMatch.frame.maxY
        try app.performAccessibilityAudit(for: types) { issue in
            guard issue.auditType == .dynamicType, let element = issue.element else { return false }
            return element.frame.maxY > edge - 180
        }
    }

    /// The player's controls hide after 3 s of playback; a tap on the video brings them back.
    func revealPlayerControls(_ app: XCUIApplication) {
        guard !app.buttons["player.minimize"].exists else { return }
        app.descendants(matching: .any)["player.video"].firstMatch.tap()
        XCTAssertTrue(app.buttons["player.minimize"].waitForExistence(timeout: 3))
    }

    /// Minimises the full player and waits until it has really gone. A tap that lands just as the
    /// controls hide only toggles them, so it tries once more; a player that won't close fails.
    func minimizePlayer(_ app: XCUIApplication) {
        let video = app.descendants(matching: .any)["player.video"]
        for _ in 0..<2 where video.exists {
            revealPlayerControls(app)
            app.buttons["player.minimize"].tap()
            _ = video.waitForNonExistence(timeout: 5)
        }
        XCTAssertFalse(video.exists, "The player didn't close")
        XCTAssertTrue(app.buttons["miniPlayer.expand"].waitForExistence(timeout: 5))
    }

    /// Attaches a named screenshot (and, under fastlane, is where `snapshot()` hooks in). It waits
    /// for the screen to settle first, so a push or sheet is never caught halfway (up to ~3 s).
    func snapshot(_ name: String, app: XCUIApplication) {
        var screenshot = app.screenshot()
        for _ in 0..<12 {
            let settled = expectation(description: "screen settles")
            settled.isInverted = true
            wait(for: [settled], timeout: 0.25)
            let next = app.screenshot()
            if next.pngRepresentation == screenshot.pngRepresentation {
                break
            }
            screenshot = next
        }
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
