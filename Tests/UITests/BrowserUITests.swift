import XCTest

/// The Browser, from Discover: the grid of sites, typing a site, links that stay in the Browser, and a direct video
/// playing in Roadivo's player. Uses example.com and Apple's public HLS
/// test stream, like the other flows.
@MainActor
final class BrowserUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// A typed site opens with its name in the address bar and Back, Forward and Reload under it, and the
    /// round menu's Start Page goes back to the grid.
    func testTypedAddressOpensAndReturns() throws {
        let app = XCUIApplication.roadivo(skipOnboarding: true)
        openBrowser(app)
        let address = app.textFields["browser.address"]
        XCTAssertTrue(address.waitForExistence(timeout: 5))
        snapshot("44-Browser-Start", app: app)
        try auditIgnoringBottomEdge(app, for: [.dynamicType, .sufficientElementDescription, .hitRegion])

        address.tap()
        address.typeText("example.com\n")
        XCTAssertTrue(app.descendants(matching: .any)["browser.web"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.textFields["browser.address"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["browser.address"].value as? String, "example.com")
        XCTAssertTrue(app.buttons["browser.back"].exists)
        XCTAssertTrue(app.buttons["browser.reload"].exists)
        snapshot("43-Browser-Page", app: app)

        // Back, at a tap: the Start Page.
        app.buttons["browser.menu"].tap()
        XCTAssertTrue(app.buttons["browser.site.Google"].waitForExistence(timeout: 5))
    }

    /// A site in the grid opens full screen in the Browser, not its app; Back's long press offers Leave Browser.
    func testSiteOpensInTheBrowser() {
        let app = XCUIApplication.roadivo(skipOnboarding: true)
        openBrowser(app)
        let site = app.buttons["browser.site.Vimeo"]
        XCTAssertTrue(site.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["browser.site.YouTube"].exists)
        snapshot("46-Browser-Sites", app: app)
        site.tap()

        XCTAssertTrue(app.descendants(matching: .any)["browser.web"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.state, .runningForeground) // Still in Roadivo, not the site's app.
        XCTAssertFalse(app.tabBars.firstMatch.isHittable) // The page has the whole screen.
        app.buttons["browser.menu"].press(forDuration: 1)
        let leave = app.buttons["browser.leave"]
        XCTAssertTrue(leave.waitForExistence(timeout: 5))
        leave.tap()
        XCTAssertTrue(app.buttons["cast.browser"].waitForExistence(timeout: 5))
    }

    /// A link straight to a video offers "Play in Roadivo", which opens Roadivo's own player.
    func testDirectVideoPlaysInRoadivo() {
        let app = XCUIApplication.roadivo(skipOnboarding: true)
        openBrowser(app)
        let address = app.textFields["browser.address"]
        XCTAssertTrue(address.waitForExistence(timeout: 5))
        address.tap()
        address.typeText(
            "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8\n"
        )

        let play = app.buttons["browser.video.play"]
        XCTAssertTrue(play.waitForExistence(timeout: 20))
        play.tap()
        XCTAssertTrue(app.descendants(matching: .any)["player.video"].waitForExistence(timeout: 10))
    }

    /// Discover › Browser.
    private func openBrowser(_ app: XCUIApplication) {
        app.tabBars.buttons["Discover"].tap()
        let row = app.buttons["cast.browser"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
    }
}
