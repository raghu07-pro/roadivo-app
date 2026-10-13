import XCTest

/// Walks every screen and attaches a screenshot of each, for design review
/// and (via fastlane's `capture_screenshots`) the App Store listing.
@MainActor
final class ScreenshotUITests: XCTestCase {
    func testCaptureFirstLaunch() {
        let app = XCUIApplication.roadivo()
        let next = app.buttons["onboarding.continue"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        for page in 1...4 {
            let title = app.staticTexts["onboarding.title.\(page - 1)"]
            XCTAssertTrue(title.waitForExistence(timeout: 5))
            waitUntilSettled(title, in: app)
            snapshot("0\(page)-Onboarding", app: app)
            next.tap()
        }
        XCTAssertTrue(app.buttons["paywall.plan.lifetime"].waitForExistence(timeout: 5))
        snapshot("05-Paywall", app: app)
        app.buttons["paywall.close"].tap()
        XCTAssertTrue(app.buttons["library.empty.addSource"].waitForExistence(timeout: 5))
        snapshot("06-Home-Empty", app: app)

        app.buttons["library.empty.addSource"].tap()
        let link = app.textFields["addSource.link"]
        XCTAssertTrue(link.waitForExistence(timeout: 5))
        snapshot("07-AddSource", app: app)
        link.tap()
        link.typeText("test")
        XCTAssertTrue(app.staticTexts["No usable link found"].waitForExistence(timeout: 2))
        snapshot("08-AddSource-Invalid", app: app)
        app.buttons["addSource.scan"].tap()
        XCTAssertTrue(app.buttons["scanner.close"].waitForExistence(timeout: 5))
        snapshot("09-Scanner", app: app)
        app.buttons["scanner.close"].tap()
        app.buttons["addSource.server.jellyfin"].tap()
        XCTAssertTrue(app.textFields["server.address"].waitForExistence(timeout: 5))
        snapshot("10-ServerLogin", app: app)
    }

    func testCaptureMainScreens() {
        let app = XCUIApplication.roadivo(skipOnboarding: true, demoLibrary: true)
        XCTAssertTrue(app.buttons["channel.Football Tonight"].waitForExistence(timeout: 10))
        snapshot("11-Home", app: app)

        let search = app.searchFields.firstMatch
        search.tap()
        search.typeText("Foot")
        snapshot("12-Search", app: app)
        app.buttons["Cancel"].firstMatch.tap()

        app.buttons["channel.Steel Horizon · 1080p"].tap()
        XCTAssertTrue(app.buttons["player.minimize"].waitForExistence(timeout: 5))
        snapshot("13-Player", app: app)
        app.buttons["player.minimize"].tap()
        XCTAssertTrue(app.buttons["miniPlayer.expand"].waitForExistence(timeout: 5))
        snapshot("14-MiniPlayer", app: app)

        app.tabBars.buttons["Favorites"].tap()
        snapshot("15-Favorites", app: app)
        app.buttons["On this iPhone"].tap()
        snapshot("16-OnThisIPhone", app: app)
        app.buttons["local.importMenu"].firstMatch.tap()
        snapshot("17-ImportMenu", app: app)
        app.tap()

        app.tabBars.buttons["Cast to Car"].tap()
        snapshot("18-Car", app: app)

        // Stop playback first: the mini player would cover the last Settings rows.
        app.buttons["miniPlayer.close"].tap()
        app.tabBars.buttons["Settings"].tap()
        snapshot("19-Settings", app: app)
        app.buttons["settings.sources"].tap()
        snapshot("20-ManageSources", app: app)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["settings.language"].tap()
        snapshot("21-Language", app: app)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["settings.privacy"].tap()
        snapshot("22-Privacy", app: app)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["settings.help"].tap()
        snapshot("23-Help", app: app)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["settings.pro"].tap()
        XCTAssertTrue(app.buttons["paywall.close"].waitForExistence(timeout: 5))
        snapshot("24-Paywall-Settings", app: app)
    }
}
