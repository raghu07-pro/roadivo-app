import XCTest

/// The opening splash plays over the app and gives way to it by itself (DECISIONS 130).
@MainActor
final class SplashUITests: XCTestCase {
    func testSplashGivesWayToTheApp() {
        let app = XCUIApplication.roadivo(skipOnboarding: true, showSplash: true)
        let addSource = app.buttons["library.empty.addSource"]
        XCTAssertTrue(addSource.waitForExistence(timeout: 10))

        // A tap while the splash plays only skips it; once it's gone the next tap opens Add a Source.
        let link = app.textFields["addSource.link"]
        let deadline = Date().addingTimeInterval(8)
        while !link.exists, Date() < deadline {
            addSource.tap()
            _ = link.waitForExistence(timeout: 1.5)
        }
        XCTAssertTrue(link.exists, "The splash never gave way to the app")
    }
}
