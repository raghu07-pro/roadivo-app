import XCTest

/// The Directions tab, with scripted Maps (two places, two routes) and a fixed location (DECISIONS 145).
@MainActor
final class DirectionsUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func openDirections(_ app: XCUIApplication) {
        app.tabBars.buttons.element(boundBy: 3).tap()
        XCTAssertTrue(app.descendants(matching: .any)["directions.screen"].waitForExistence(timeout: 5))
    }

    /// Searches "cabo" and picks the first place.
    private func chooseFirstPlace(_ app: XCUIApplication) {
        let field = app.textFields["search.field"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("cabo")
        let place = app.buttons["directions.place.0"]
        XCTAssertTrue(place.waitForExistence(timeout: 5))
        place.tap()
    }

    /// Before a search, a hint says what the tab does.
    func testOpensWithAHint() {
        let app = XCUIApplication.roadivo(skipOnboarding: true)
        openDirections(app)
        XCTAssertTrue(app.descendants(matching: .any)["directions.hint"].waitForExistence(timeout: 5))
    }

    /// Typing lists places; picking one shows its route, the other route to pick, and Apple Maps.
    func testSearchShowsTheRoute() {
        let app = XCUIApplication.roadivo(skipOnboarding: true)
        openDirections(app)
        chooseFirstPlace(app)
        XCTAssertTrue(app.descendants(matching: .any)["directions.summary"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["directions.openMaps"].isEnabled)
        XCTAssertFalse(app.buttons["directions.place.0"].exists, "The list should close once a place is chosen")
        XCTAssertFalse(app.keyboards.firstMatch.exists, "The keyboard should close so the map has the screen")
    }

    /// Cancel leaves the search: the text clears, the keyboard closes and the hint comes back.
    func testCancelClosesTheKeyboard() {
        let app = XCUIApplication.roadivo(skipOnboarding: true)
        openDirections(app)
        let field = app.textFields["search.field"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("ca")
        let cancel = app.buttons["directions.cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        cancel.tap()
        XCTAssertFalse(app.keyboards.firstMatch.waitForExistence(timeout: 2))
        XCTAssertFalse(cancel.exists)
        XCTAssertTrue(app.descendants(matching: .any)["directions.hint"].waitForExistence(timeout: 5))
    }

    /// The hint sits just above the tab bar, not floating mid-screen.
    func testHintSitsAtTheBottom() {
        let app = XCUIApplication.roadivo(skipOnboarding: true)
        openDirections(app)
        let hint = app.descendants(matching: .any)["directions.hint"]
        XCTAssertTrue(hint.waitForExistence(timeout: 5))
        let gap = app.tabBars.firstMatch.frame.minY - hint.frame.maxY
        XCTAssertLessThan(gap, 60, "The hint is \(gap) pt above the tab bar")
    }

    /// The second route can be picked, and becomes the selected one.
    func testPickingTheOtherRoute() {
        let app = XCUIApplication.roadivo(skipOnboarding: true)
        openDirections(app)
        chooseFirstPlace(app)
        let fastest = app.buttons["directions.choice.0"]
        let other = app.buttons["directions.choice.1"]
        XCTAssertTrue(other.waitForExistence(timeout: 5))
        XCTAssertTrue(fastest.isSelected)
        other.tap()
        XCTAssertTrue(other.isSelected)
        XCTAssertFalse(fastest.isSelected)
    }

    /// An open route follows to the other tabs as a small card; a tap goes back to it, ✕ ends it.
    func testRouteCardOnOtherTabs() throws {
        let app = XCUIApplication.roadivo(skipOnboarding: true)
        openDirections(app)
        XCTAssertFalse(app.buttons["directions.miniRoute"].exists)
        chooseFirstPlace(app)
        XCTAssertTrue(app.buttons["directions.openMaps"].waitForExistence(timeout: 5))

        app.tabBars.buttons.element(boundBy: 0).tap()
        let card = app.buttons["directions.miniRoute"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        try app.performAccessibilityAudit(for: [.sufficientElementDescription, .hitRegion])
        card.tap()
        XCTAssertTrue(app.buttons["directions.openMaps"].waitForExistence(timeout: 5), "The tap should open the route")

        app.tabBars.buttons.element(boundBy: 2).tap()
        let end = app.buttons["directions.miniRoute.end"]
        XCTAssertTrue(end.waitForExistence(timeout: 5))
        end.tap()
        XCTAssertFalse(card.waitForExistence(timeout: 2))
        openDirections(app)
        XCTAssertTrue(app.descendants(matching: .any)["directions.hint"].waitForExistence(timeout: 5))
    }

    /// Close clears the route and brings the hint back.
    func testCloseClearsTheRoute() {
        let app = XCUIApplication.roadivo(skipOnboarding: true)
        openDirections(app)
        chooseFirstPlace(app)
        let close = app.buttons["directions.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        close.tap()
        XCTAssertFalse(app.descendants(matching: .any)["directions.route"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.descendants(matching: .any)["directions.hint"].waitForExistence(timeout: 5))
    }

    /// With Location off, the tab says so and offers Settings, and a chosen place waits for it.
    func testLocationOffOffersSettings() {
        let app = XCUIApplication.roadivo(skipOnboarding: true, locationDenied: true)
        openDirections(app)
        XCTAssertTrue(app.buttons["directions.openSettings"].waitForExistence(timeout: 5))
        chooseFirstPlace(app)
        let route = app.descendants(matching: .any)["directions.route"]
        XCTAssertTrue(route.waitForExistence(timeout: 5))
        XCTAssertTrue(route.descendants(matching: .any)["directions.locationOff"].exists)
        XCTAssertFalse(app.buttons["directions.openMaps"].exists)
    }

    func testDirectionsAccessibilityAudit() throws {
        let app = XCUIApplication.roadivo(skipOnboarding: true)
        openDirections(app)
        try app.performAccessibilityAudit(for: .all, Self.ignoringKnownIssues)
        chooseFirstPlace(app)
        XCTAssertTrue(app.buttons["directions.openMaps"].waitForExistence(timeout: 5))
        try app.performAccessibilityAudit(for: .all, Self.ignoringKnownIssues)
    }

    /// Three named exceptions; every other issue still fails the audit.
    private static func ignoringKnownIssues(_ issue: XCUIAccessibilityAuditIssue) -> Bool {
        // Apple's own "Legal" link on the map (MKAttributionLabel): MapKit draws its small hit area.
        if issue.auditType == .hitRegion, issue.detailedDescription.contains("MKAttributionLabel") {
            return true
        }
        // The one-line search field's placeholder truncates at the largest sizes, as the system search bar's does;
        // typed text scrolls inside the field. Home's audits leave out this check altogether.
        if issue.auditType == .textClipped, issue.element?.identifier == "search.field" {
            return true
        }
        // Place names MapKit draws into the map image are found on screen with no element behind them; the map
        // gives VoiceOver its places itself, and every Roadivo label here is a real Text.
        if issue.auditType == .elementDetection, issue.element == nil {
            return true
        }
        // A step in the log naming the element to fix; the failure alone is a one-line summary.
        let element = issue.element.map { "'\($0.identifier)' \($0.elementType.rawValue) at \($0.frame)" } ?? "none"
        XCTContext.runActivity(named: "Audit \(issue.auditType.rawValue): \(element)") { _ in }
        return false
    }
}
