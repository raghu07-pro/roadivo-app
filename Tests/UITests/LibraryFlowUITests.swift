import XCTest

@MainActor
final class LibraryFlowUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// The player shows only its own controls on the video, and the group as a grid below.
    func testPlayerShowsNowPlaying() throws {
        let app = XCUIApplication.roadivo(skipOnboarding: true, demoLibrary: true)
        let channel = app.buttons["channel.Football Tonight"]
        XCTAssertTrue(channel.waitForExistence(timeout: 10))
        channel.tap()
        XCTAssertTrue(app.buttons["player.favorite"].waitForExistence(timeout: 5))
        for control in [
            "player.minimize",
            "player.close",
            "player.playPause",
            "player.rotationLock",
            "player.fullScreen",
            "player.carMode"
        ] {
            XCTAssertTrue(app.buttons[control].exists, control)
        }
        XCTAssertTrue(app.buttons["upNext.Football Tonight"].exists)
        snapshot("13-Player", app: app)
        try auditIgnoringBottomEdge(app, for: [.dynamicType, .sufficientElementDescription, .hitRegion])

        revealPlayerControls(app)
        app.buttons["player.minimize"].tap()
        app.buttons["miniPlayer.close"].tap()
        app.tabBars.buttons.element(boundBy: 3).tap()
        app.buttons["settings.theme"].tap()
        app.buttons["theme.appearance.dark"].tap()
        app.tabBars.buttons.element(boundBy: 0).tap()
        // Now also under Continue Watching, so take the first card.
        channel.firstMatch.tap()
        XCTAssertTrue(app.buttons["player.favorite"].waitForExistence(timeout: 5))
        snapshot("13-Player-Dark", app: app)
    }

    /// Chips under the video browse the source's other groups while one plays.
    func testPlayerChipsBrowseOtherGroups() {
        let app = XCUIApplication.roadivo(skipOnboarding: true, demoLibrary: true)
        let channel = app.buttons["channel.Steel Horizon · 1080p"]
        XCTAssertTrue(channel.waitForExistence(timeout: 10))
        channel.tap()

        let movies = app.buttons["player.group.Movies"]
        XCTAssertTrue(movies.waitForExistence(timeout: 5))
        XCTAssertTrue(movies.isSelected)
        XCTAssertFalse(app.buttons["upNext.Football Tonight"].exists)

        app.buttons["player.group.Sports"].tap()
        let football = app.buttons["upNext.Football Tonight"]
        XCTAssertTrue(football.waitForExistence(timeout: 5))
        football.tap()
        XCTAssertTrue(waitForSelection(football))
        XCTAssertTrue(app.buttons["player.group.Sports"].isSelected)
    }

    /// Home's one button filters by source (with each source's count) and holds Add Source.
    func testHomeFiltersBySource() {
        let app = XCUIApplication.roadivo(skipOnboarding: true, demoLibrary: true)
        XCTAssertTrue(app.buttons["channel.Football Tonight"].waitForExistence(timeout: 10))
        let menu = app.buttons["library.sourceFilter"]
        XCTAssertTrue(menu.exists)
        menu.tap()

        let roadTrip = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Road Trip'")).firstMatch
        XCTAssertTrue(roadTrip.waitForExistence(timeout: 5))
        XCTAssertTrue(roadTrip.label.contains("13"))
        XCTAssertTrue(app.buttons["library.menu.addSource"].exists)
        snapshot("11b-SourceMenu", app: app)
        roadTrip.tap()

        XCTAssertEqual(menu.value as? String, "Road Trip")
        XCTAssertTrue(app.buttons["channel.Football Tonight"].exists)
    }

    /// See All opens a group as a grid, with chips to move to another group.
    func testSeeAllSwitchesGroups() throws {
        let app = XCUIApplication.roadivo(skipOnboarding: true, demoLibrary: true)
        let seeAll = app.buttons["library.seeAll.Movies"]
        XCTAssertTrue(seeAll.waitForExistence(timeout: 10))
        seeAll.tap()

        let movies = app.buttons["group.Movies"]
        XCTAssertTrue(movies.waitForExistence(timeout: 5))
        XCTAssertTrue(movies.isSelected)
        XCTAssertTrue(app.buttons["channel.Steel Horizon · 1080p"].exists)
        snapshot("12b-SeeAll", app: app)

        app.buttons["group.Travel"].tap()
        XCTAssertTrue(app.buttons["channel.Coastal Echoes"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["channel.Steel Horizon · 1080p"].exists)
        try auditIgnoringBottomEdge(app, for: [.dynamicType, .sufficientElementDescription, .hitRegion])
    }

    private func waitForSelection(_ element: XCUIElement) -> Bool {
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isSelected == true"), object: element)
        return XCTWaiter().wait(for: [selected], timeout: 5) == .completed
    }

    /// The mini player floats over every tab, so each screen keeps its content clear of it: the Car
    /// tab's safety note, and the last Settings row once scrolled to the end.
    func testMiniPlayerNeverCoversContent() {
        let app = XCUIApplication.roadivo(skipOnboarding: true, demoLibrary: true)
        let channel = app.buttons["channel.Football Tonight"]
        XCTAssertTrue(channel.waitForExistence(timeout: 10))
        channel.tap()
        let minimize = app.buttons["player.minimize"]
        XCTAssertTrue(minimize.waitForExistence(timeout: 5))
        minimize.tap()
        let miniPlayer = app.buttons["miniPlayer.expand"]
        XCTAssertTrue(miniPlayer.waitForExistence(timeout: 5))

        app.tabBars.buttons["Discover"].tap()
        let lastOption = app.buttons["cast.fromApp"]
        XCTAssertTrue(lastOption.waitForExistence(timeout: 5))
        XCTAssertLessThanOrEqual(lastOption.frame.maxY, miniPlayer.frame.minY)

        app.tabBars.buttons["Settings"].tap()
        let list = app.collectionViews.firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        for _ in 0..<4 {
            list.swipeUp()
        }
        let lastRow = app.cells.allElementsBoundByIndex.last { $0.frame.height > 0 }
        XCTAssertLessThanOrEqual(lastRow?.frame.maxY ?? .infinity, miniPlayer.frame.minY)
    }

    /// Minimise keeps playing in the mini player; close stops it.
    func testPlayMinimizeAndClose() {
        let app = XCUIApplication.roadivo(skipOnboarding: true, demoLibrary: true)
        let channel = app.buttons["channel.Football Tonight"]
        XCTAssertTrue(channel.waitForExistence(timeout: 10))
        channel.tap()

        let minimize = app.buttons["player.minimize"]
        XCTAssertTrue(minimize.waitForExistence(timeout: 5))
        // Straight to the player: no mini player behind it.
        XCTAssertFalse(app.buttons["miniPlayer.expand"].exists)
        minimize.tap()

        let miniPlayer = app.buttons["miniPlayer.expand"]
        XCTAssertTrue(miniPlayer.waitForExistence(timeout: 5))
        miniPlayer.tap()
        revealPlayerControls(app)
        app.buttons["player.close"].tap()
        XCTAssertFalse(miniPlayer.waitForExistence(timeout: 2))
    }

    func testSearchFiltersHome() {
        let app = XCUIApplication.roadivo(skipOnboarding: true, demoLibrary: true)
        XCTAssertTrue(app.buttons["channel.Football Tonight"].waitForExistence(timeout: 10))
        let search = app.textFields["search.field"]
        search.tap()
        search.typeText("coastal")
        XCTAssertTrue(app.buttons["channel.Coastal Echoes"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["channel.Football Tonight"].exists)
        app.buttons["search.clear"].tap()
        XCTAssertTrue(app.buttons["channel.Football Tonight"].waitForExistence(timeout: 5))
    }

    /// The real speech path: answering the permission alerts and listening must not crash. iOS calls
    /// these back off the main thread, which crashed the first version on a device.
    func testLiveVoiceSearchSurvivesPermissionsAndListening() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-skip-onboarding", "-demo-library", "-live-voice"]
        app.resetAuthorizationStatus(for: .microphone)
        app.launch()
        let mic = app.buttons["search.mic"]
        XCTAssertTrue(mic.waitForExistence(timeout: 10))
        mic.tap()

        // Speech recognition, then microphone: allow whichever iOS asks for.
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons.matching(NSPredicate(format: "label IN %@", ["Allow", "OK"])).firstMatch
        for _ in 0..<2 where allow.waitForExistence(timeout: 5) {
            allow.tap()
        }
        RunLoop.current.run(until: Date().addingTimeInterval(3))
        XCTAssertEqual(app.state, .runningForeground, "The app stopped after the permission prompts")
        XCTAssertTrue(mic.exists)
        snapshot("34-Live-Voice", app: app)
        // Stop listening, or close the "allow" / "unavailable" alert, whichever showed.
        if app.alerts.firstMatch.exists {
            app.alerts.firstMatch.buttons.firstMatch.tap()
        } else {
            mic.tap()
        }
        RunLoop.current.run(until: Date().addingTimeInterval(2))
        XCTAssertEqual(app.state, .runningForeground, "The app stopped when listening ended")
    }

    /// The mic in the search bar fills the search with what's said (a scripted "Football" here).
    func testVoiceSearchFillsTheSearch() {
        let app = XCUIApplication.roadivo(skipOnboarding: true, demoLibrary: true)
        XCTAssertTrue(app.buttons["channel.Coastal Echoes"].waitForExistence(timeout: 10))
        app.buttons["search.mic"].tap()
        let search = app.textFields["search.field"]
        expectation(for: NSPredicate(format: "value == %@", "Football"), evaluatedWith: search)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(app.buttons["channel.Football Tonight"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["channel.Coastal Echoes"].exists)
        snapshot("33-Voice-Search", app: app)
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

    func testSecondSourceAsksFreeUsersForPro() {
        let app = XCUIApplication.roadivo(skipOnboarding: true, demoLibrary: true)
        XCTAssertTrue(app.buttons["channel.Football Tonight"].waitForExistence(timeout: 10))
        // With a source, Home's one button is the source menu, which holds Add Source.
        XCTAssertFalse(app.buttons["library.addSource"].exists)
        app.buttons["library.sourceFilter"].tap()
        let add = app.buttons["library.menu.addSource"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
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

    /// All four server types are offered; Plex shows a code for plex.tv/link (a scripted one here).
    func testAddSourceOffersFourServersAndPlexCode() throws {
        let app = XCUIApplication.roadivo(skipOnboarding: true)
        app.buttons["library.empty.addSource"].tap()
        for kind in ["jellyfin", "emby", "xtream", "plex"] {
            XCTAssertTrue(app.buttons["addSource.server.\(kind)"].waitForExistence(timeout: 5), kind)
        }
        XCTAssertFalse(app.buttons["addSource.submit"].isEnabled)
        snapshot("07-AddSource", app: app)
        app.buttons["addSource.whatIsSource"].tap()
        // Tips for finding the user's own link and a way to Help & FAQ; no web search for playlists.
        let help = app.buttons["whatIsSource.help"]
        XCTAssertTrue(help.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["whatIsSource.search"].exists)
        snapshot("07b-WhatIsASource", app: app)
        try auditIgnoringBottomEdge(app, for: [.dynamicType, .sufficientElementDescription, .hitRegion])
        help.tap()
        let contact = app.buttons["help.contactSupport"]
        if !contact.waitForExistence(timeout: 3) {
            app.swipeUp() // Below the questions on shorter iPhones.
        }
        XCTAssertTrue(contact.waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(help.waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.swipeUp() // On shorter iPhones the server cards start at the bottom edge, where text can't grow.
        try auditIgnoringBottomEdge(app, for: [.dynamicType, .sufficientElementDescription, .hitRegion])

        app.buttons["addSource.server.jellyfin"].tap()
        let password = app.secureTextFields["server.password"]
        XCTAssertTrue(password.waitForExistence(timeout: 5))
        app.buttons["Show password"].tap()
        XCTAssertTrue(app.textFields["server.password"].waitForExistence(timeout: 2))
        snapshot("10-ServerLogin", app: app)
        app.navigationBars.buttons.element(boundBy: 0).tap()

        app.buttons["addSource.server.plex"].tap()
        let code = app.staticTexts["plex.code"]
        XCTAssertTrue(code.waitForExistence(timeout: 5))
        XCTAssertEqual(code.label, "R D V O")
        XCTAssertTrue(app.buttons["plex.open"].exists)
        app.buttons["plex.copy"].tap()
        // iOS stops a test reading the clipboard, so check the button's own confirmation instead.
        XCTAssertTrue(app.buttons["Copied"].waitForExistence(timeout: 2))
        snapshot("10b-PlexCode", app: app)
    }

    func testHomeAccessibilityAudit() throws {
        let app = XCUIApplication.roadivo(skipOnboarding: true, demoLibrary: true)
        XCTAssertTrue(app.buttons["channel.Football Tonight"].waitForExistence(timeout: 10))
        try app.performAccessibilityAudit(for: [.dynamicType, .sufficientElementDescription, .hitRegion])
    }
}
