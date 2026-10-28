import XCTest

/// The Directions tab, with scripted Maps (two places, two routes) and a fixed location (DECISIONS 145).
@MainActor
final class DirectionsUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Skips while `PLAYCARTV_DIRECTIONS` is NO: the tab is kept for a later release (DECISIONS 149).
    private func openDirections(_ app: XCUIApplication) throws {
        guard let tab = app.directionsTab else {
            throw XCTSkip("Directions is switched off (PLAYCARTV_DIRECTIONS = NO)")
        }
        tab.tap()
        XCTAssertTrue(app.descendants(matching: .any)["directions.screen"].waitForExistence(timeout: 5))
    }

    /// Searches "cabo" and picks the first place.
    private func chooseFirstPlace(_ app: XCUIApplication) {
        openSearch(app)
        let field = app.textFields["search.field"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("cabo")
        let place = app.buttons["directions.place.0"]
        XCTAssertTrue(place.waitForExistence(timeout: 5))
        place.tap()
    }

    /// The search field shows only from the search button above the location arrow (DECISIONS 172).
    private func openSearch(_ app: XCUIApplication) {
        let search = app.buttons["directions.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["directions.locate"].exists, "The location arrow sits under the search button")
        XCTAssertFalse(app.textFields["search.field"].exists, "The field waits for the search button")
        search.tap()
    }

    /// Before a search, a hint says what the tab does.
    func testOpensWithAHint() throws {
        let app = XCUIApplication.playcartv(skipOnboarding: true)
        try openDirections(app)
        XCTAssertTrue(app.descendants(matching: .any)["directions.hint"].waitForExistence(timeout: 5))
    }

    /// Typing lists places; picking one shows its route and the other route to pick, with no Apple Maps button.
    func testSearchShowsTheRoute() throws {
        let app = XCUIApplication.playcartv(skipOnboarding: true)
        try openDirections(app)
        chooseFirstPlace(app)
        XCTAssertTrue(app.descendants(matching: .any)["directions.summary"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["directions.openMaps"].exists, "Apple Maps' button was removed (DECISIONS 172)")
        XCTAssertFalse(app.buttons["directions.place.0"].exists, "The list should close once a place is chosen")
        XCTAssertFalse(app.keyboards.firstMatch.exists, "The keyboard should close so the map has the screen")
    }

    /// The search button opens the field; Cancel leaves it: the text clears, the keyboard closes and the button and
    /// hint come back.
    func testCancelClosesTheKeyboard() throws {
        let app = XCUIApplication.playcartv(skipOnboarding: true)
        try openDirections(app)
        openSearch(app)
        let field = app.textFields["search.field"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "The button opens the field ready to type")
        field.typeText("ca")
        let cancel = app.buttons["directions.cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        cancel.tap()
        XCTAssertFalse(app.keyboards.firstMatch.waitForExistence(timeout: 2))
        XCTAssertFalse(cancel.exists)
        XCTAssertFalse(field.exists, "Cancel puts the search button back")
        XCTAssertTrue(app.buttons["directions.search"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["directions.hint"].waitForExistence(timeout: 5))
    }

    /// The hint sits just above the tab bar, not floating mid-screen.
    func testHintSitsAtTheBottom() throws {
        let app = XCUIApplication.playcartv(skipOnboarding: true)
        try openDirections(app)
        let hint = app.descendants(matching: .any)["directions.hint"]
        XCTAssertTrue(hint.waitForExistence(timeout: 5))
        let gap = app.tabBars.firstMatch.frame.minY - hint.frame.maxY
        XCTAssertLessThan(gap, 60, "The hint is \(gap) pt above the tab bar")
    }

    /// The second route can be picked, which folds the card, and becomes the selected one.
    func testPickingTheOtherRoute() throws {
        let app = XCUIApplication.playcartv(skipOnboarding: true)
        try openDirections(app)
        chooseFirstPlace(app)
        let fastest = app.buttons["directions.choice.0"]
        let other = app.buttons["directions.choice.1"]
        XCTAssertTrue(other.waitForExistence(timeout: 5))
        XCTAssertTrue(fastest.isSelected)
        other.tap()
        // Picking a route folds the card so the map shows it; opening the card shows the pick (DECISIONS 172).
        let expand = app.buttons["directions.expand"]
        XCTAssertTrue(expand.waitForExistence(timeout: 5), "Picking a route should fold the card")
        XCTAssertFalse(other.exists)
        expand.tap()
        XCTAssertTrue(other.waitForExistence(timeout: 5))
        XCTAssertTrue(other.isSelected)
        XCTAssertFalse(fastest.isSelected)
    }

    /// An open route follows to the other tabs as a small card; a tap goes back to it, ✕ ends it.
    func testRouteCardOnOtherTabs() throws {
        let app = XCUIApplication.playcartv(skipOnboarding: true)
        try openDirections(app)
        XCTAssertFalse(app.buttons["directions.miniRoute"].exists)
        chooseFirstPlace(app)
        let summary = app.descendants(matching: .any)["directions.summary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 5))

        app.tabBars.buttons.element(boundBy: 0).tap()
        let card = app.buttons["directions.miniRoute"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        try app.performAccessibilityAudit(for: [.sufficientElementDescription, .hitRegion])
        card.tap()
        XCTAssertTrue(summary.waitForExistence(timeout: 5), "The tap should open the route")

        app.tabBars.buttons.element(boundBy: 2).tap()
        let end = app.buttons["directions.miniRoute.end"]
        XCTAssertTrue(end.waitForExistence(timeout: 5))
        end.tap()
        XCTAssertFalse(card.waitForExistence(timeout: 2))
        try openDirections(app)
        XCTAssertTrue(app.descendants(matching: .any)["directions.hint"].waitForExistence(timeout: 5))
    }

    /// Close clears the route and brings the hint back.
    func testCloseClearsTheRoute() throws {
        let app = XCUIApplication.playcartv(skipOnboarding: true)
        try openDirections(app)
        chooseFirstPlace(app)
        let close = app.buttons["directions.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        close.tap()
        XCTAssertFalse(app.descendants(matching: .any)["directions.route"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.descendants(matching: .any)["directions.hint"].waitForExistence(timeout: 5))
    }

    /// With Location off, the tab says so and offers Settings, and a chosen place waits for it.
    func testLocationOffOffersSettings() throws {
        let app = XCUIApplication.playcartv(skipOnboarding: true, locationDenied: true)
        try openDirections(app)
        XCTAssertTrue(app.buttons["directions.openSettings"].waitForExistence(timeout: 5))
        chooseFirstPlace(app)
        let route = app.descendants(matching: .any)["directions.route"]
        XCTAssertTrue(route.waitForExistence(timeout: 5))
        XCTAssertTrue(route.descendants(matching: .any)["directions.locationOff"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["directions.summary"].exists)
    }

    func testDirectionsAccessibilityAudit() throws {
        let app = XCUIApplication.playcartv(skipOnboarding: true)
        try openDirections(app)
        try app.performAccessibilityAudit(for: .all, Self.ignoringKnownIssues)
        chooseFirstPlace(app)
        XCTAssertTrue(app.descendants(matching: .any)["directions.summary"].waitForExistence(timeout: 5))
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
        // gives VoiceOver its places itself, and every PlayCarTV label here is a real Text.
        if issue.auditType == .elementDetection, issue.element == nil {
            return true
        }
        // A step in the log naming the element to fix; the failure alone is a one-line summary.
        let element = issue.element.map { "'\($0.identifier)' \($0.elementType.rawValue) at \($0.frame)" } ?? "none"
        XCTContext.runActivity(named: "Audit \(issue.auditType.rawValue): \(element)") { _ in }
        return false
    }
}
