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
}
