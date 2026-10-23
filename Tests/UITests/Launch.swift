import XCTest

extension XCUIApplication {
    /// Launches with in-memory storage and a fake App Store so every UI test
    /// starts clean. `skipOnboarding` also skips the intro paywall.
    /// `restorable`: a Yearly plan bought earlier, which only Restore brings back.
    /// `carConnected`: the iPhone acts as if plugged into a car (CarPlay audio).
    /// `demoHistory`: the demo library with a film part-watched and a channel played.
    /// `broadcasting`: Screen Broadcast counts as running, which needs a real iPhone.
    /// `showSplash`: plays the opening splash, which UI tests otherwise skip.
    /// `locationDenied`: Location is off for Roadivo, for Directions.
    static func roadivo(
        skipOnboarding: Bool = false,
        demoLibrary: Bool = false,
        demoHistory: Bool = false,
        pro: Bool = false,
        restorable: Bool = false,
        carConnected: Bool = false,
        broadcasting: Bool = false,
        showSplash: Bool = false,
        locationDenied: Bool = false
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        if skipOnboarding {
            app.launchArguments.append("-skip-onboarding")
        }
        if demoLibrary || demoHistory {
            app.launchArguments.append("-demo-library")
        }
        if demoHistory {
            app.launchArguments.append("-demo-history")
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
        if broadcasting {
            app.launchArguments.append("-broadcasting")
        }
        if showSplash {
            app.launchArguments.append("-show-splash")
        }
        if locationDenied {
            app.launchArguments.append("-location-denied")
        }
        app.launch()
        return app
    }

    /// Settings is always the last tab, in any language and whether or not Directions shows (DECISIONS 149).
    var settingsTab: XCUIElement {
        let tabs = tabBars.buttons
        _ = tabs.firstMatch.waitForExistence(timeout: 5)
        return tabs.element(boundBy: max(0, tabs.count - 1))
    }

    /// Directions is the fourth of five tabs while `ROADIVO_DIRECTIONS` is YES; nil while it's switched off.
    var directionsTab: XCUIElement? {
        let tabs = tabBars.buttons
        _ = tabs.firstMatch.waitForExistence(timeout: 5)
        return tabs.count == 5 ? tabs.element(boundBy: 3) : nil
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
    /// `alsoIgnoring`: labels of specific elements with the same false positive just above that band,
    /// each named with its reason at the call site.
    func auditIgnoringBottomEdge(
        _ app: XCUIApplication,
        for types: XCUIAccessibilityAuditType,
        alsoIgnoring labels: Set<String> = []
    ) throws {
        let tabBar = app.tabBars.firstMatch
        let edge = tabBar.exists ? tabBar.frame.minY : app.windows.firstMatch.frame.maxY
        try app.performAccessibilityAudit(for: types) { issue in
            guard issue.auditType == .dynamicType, let element = issue.element else { return false }
            let isIgnored = element.frame.maxY > edge - 180 || labels.contains(element.label)
            if !isIgnored { // A step in the test's log naming what to fix; the failure alone is a one-line summary.
                let detail = "'\(element.label)' at \(element.frame): \(issue.detailedDescription)"
                XCTContext.runActivity(named: "Audit: \(detail)") { _ in }
            }
            return isIgnored
        }
    }

    /// The player's controls hide after a few seconds of playback (2 minutes under UI tests); a tap on the video brings
    /// them back.
    func revealPlayerControls(_ app: XCUIApplication) {
        guard !app.buttons["player.minimize"].exists else { return }
        app.descendants(matching: .any)["player.video"].firstMatch.tap()
        XCTAssertTrue(app.buttons["player.minimize"].waitForExistence(timeout: 3))
    }

    /// A page's ? opens its steps in a sheet (they're no longer on the page), which passes the audit and
    /// closes with its ✕ (DECISIONS 128).
    func checkStepsHelp(_ app: XCUIApplication, identifier: String, snapshot name: String) throws {
        let steps = app.descendants(matching: .any)["\(identifier).steps"]
        XCTAssertFalse(steps.exists, "The steps belong in the ? sheet")
        let help = app.buttons["\(identifier).help"]
        XCTAssertTrue(help.waitForExistence(timeout: 5))
        help.tap()
        XCTAssertTrue(steps.waitForExistence(timeout: 5))
        snapshot(name, app: app)
        try auditIgnoringBottomEdge(app, for: [.dynamicType, .sufficientElementDescription, .hitRegion])
        app.buttons["\(identifier).done"].tap()
        XCTAssertTrue(steps.waitForNonExistence(timeout: 5))
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
