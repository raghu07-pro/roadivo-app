import XCTest

@MainActor
final class SourcesFlowUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testDeletingASourceAsksFirst() {
        let app = XCUIApplication.roadivo(skipOnboarding: true, demoLibrary: true)
        XCTAssertTrue(app.buttons["channel.Football Tonight"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Settings"].tap()
        app.buttons["settings.sources"].tap()

        let row = app.descendants(matching: .any)["source.Road Trip"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.swipeLeft()
        app.buttons["source.delete"].tap()

        // The swipe alone deletes nothing: the source stays until confirmed.
        let confirm = app.buttons["sources.confirmDelete"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        XCTAssertTrue(row.exists)

        confirm.tap()
        XCTAssertTrue(row.waitForNonExistence(timeout: 5))
    }

    /// A source opens its own channels: a chip per group, and a More menu to rename or delete it.
    func testSourceShowsItsChannelsByGroup() throws {
        let app = XCUIApplication.roadivo(skipOnboarding: true, demoLibrary: true)
        XCTAssertTrue(app.buttons["channel.Football Tonight"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Settings"].tap()
        app.buttons["settings.sources"].tap()
        let row = app.descendants(matching: .any)["source.Road Trip"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()

        // Opens on the first group, like the reference app.
        let sports = app.buttons["group.Sports"]
        XCTAssertTrue(sports.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["group.Movies"].isSelected)
        XCTAssertTrue(app.buttons["channel.Steel Horizon · 1080p"].exists)
        XCTAssertFalse(app.buttons["channel.Football Tonight"].exists)
        snapshot("20b-SourceChannels", app: app)
        try auditIgnoringBottomEdge(app, for: [.dynamicType, .sufficientElementDescription, .hitRegion])

        sports.tap()
        XCTAssertTrue(app.buttons["channel.Football Tonight"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["channel.Steel Horizon · 1080p"].exists)
        XCTAssertTrue(sports.isSelected)

        // A pasted list has no link: no Refresh and no Copy Link, but Rename and Delete.
        XCTAssertFalse(app.buttons["source.refresh"].exists)
        app.buttons["source.more"].tap()
        let delete = app.buttons["source.deleteSource"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["source.copyLink"].exists)
        delete.tap()
        let confirm = app.buttons["source.confirmDelete"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()

        // Back on Manage Sources, without the source.
        XCTAssertTrue(app.buttons["sources.add"].waitForExistence(timeout: 5))
        XCTAssertTrue(row.waitForNonExistence(timeout: 5))
    }

    /// A channel on a source's screen plays once; closing the player leaves that one screen, and Back
    /// returns to Manage Sources (it never opens the same screen again).
    func testPlayingFromASourceKeepsOneScreen() {
        let app = XCUIApplication.roadivo(skipOnboarding: true, demoLibrary: true)
        XCTAssertTrue(app.buttons["channel.Football Tonight"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Settings"].tap()
        app.buttons["settings.sources"].tap()
        let row = app.descendants(matching: .any)["source.Road Trip"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        let sports = app.buttons["group.Sports"]
        XCTAssertTrue(sports.waitForExistence(timeout: 5))
        sports.tap()

        for title in ["Football Tonight", "Track & Field"] {
            let channel = app.buttons["channel.\(title)"]
            XCTAssertTrue(channel.waitForExistence(timeout: 5), title)
            channel.tap()
            XCTAssertTrue(app.buttons["player.favorite"].waitForExistence(timeout: 5), title)
            revealPlayerControls(app)
            app.buttons["player.minimize"].tap()
            XCTAssertTrue(sports.waitForExistence(timeout: 5), title)
        }

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertFalse(sports.exists)
    }
}
