import XCTest

/// Continue Watching: a part-watched film shows how far it got, can start over, and can be removed.
@MainActor
final class ContinueWatchingUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func continueWatchingRow(_ app: XCUIApplication) -> XCUIElement {
        let row = app.descendants(matching: .any)["library.continueWatching"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        return row
    }

    /// The film reads out its time left; the live channel, with no place to pick up, its group.
    func testRowShowsProgressAndRemovesItems() throws {
        let app = XCUIApplication.playcartv(skipOnboarding: true, demoHistory: true)
        let row = continueWatchingRow(app)
        let film = row.buttons["channel.Steel Horizon · 1080p"]
        let channel = row.buttons["channel.Football Tonight"]
        XCTAssertTrue(film.waitForExistence(timeout: 5))
        XCTAssertTrue(channel.exists)
        XCTAssertEqual(film.value as? String, "35 min left")
        XCTAssertEqual(channel.value as? String, "Sports")
        snapshot("38-Continue-Watching", app: app)
        try auditIgnoringBottomEdge(app, for: [.dynamicType, .sufficientElementDescription, .hitRegion])

        film.press(forDuration: 1.2)
        XCTAssertTrue(app.buttons["Play from Beginning"].waitForExistence(timeout: 5))
        let remove = app.buttons["Remove from Continue Watching"]
        XCTAssertTrue(remove.exists)
        snapshot("39-Continue-Watching-Menu", app: app)
        remove.tap()
        XCTAssertTrue(film.waitForNonExistence(timeout: 5))
        XCTAssertTrue(channel.exists)

        // A live channel has no place to start over from, but can still be removed.
        channel.press(forDuration: 1.2)
        XCTAssertTrue(app.buttons["Remove from Continue Watching"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Play from Beginning"].exists)
        app.buttons["Remove from Continue Watching"].tap()
        XCTAssertTrue(row.waitForNonExistence(timeout: 5))
    }

    /// The film still shows its place in its group's row, where Continue Watching's actions aren't offered.
    func testGroupRowShowsProgressWithoutHistoryActions() {
        let app = XCUIApplication.playcartv(skipOnboarding: true, demoHistory: true)
        _ = continueWatchingRow(app)
        let inGroup = app.buttons.matching(identifier: "channel.Steel Horizon · 1080p").element(boundBy: 1)
        XCTAssertTrue(inGroup.waitForExistence(timeout: 5))
        XCTAssertEqual(inGroup.value as? String, "35 min left")
        inGroup.press(forDuration: 1.2)
        XCTAssertTrue(app.buttons["Add to Favorites"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Remove from Continue Watching"].exists)
    }

    func testPlayFromBeginningOpensThePlayer() {
        let app = XCUIApplication.playcartv(skipOnboarding: true, demoHistory: true)
        let film = continueWatchingRow(app).buttons["channel.Steel Horizon · 1080p"]
        XCTAssertTrue(film.waitForExistence(timeout: 5))
        film.press(forDuration: 1.2)
        let fromBeginning = app.buttons["Play from Beginning"]
        XCTAssertTrue(fromBeginning.waitForExistence(timeout: 5))
        fromBeginning.tap()
        XCTAssertTrue(app.buttons["player.favorite"].waitForExistence(timeout: 5))
    }
}
