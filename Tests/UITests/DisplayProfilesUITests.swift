import XCTest

/// Car & Display Profiles: saved for the connected car, edited, and listed in Settings.
/// `-car-connected` stands in for CarPlay audio, which a simulator can't have.
@MainActor
final class DisplayProfilesUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testSaveAndEditProfileFromSettings() throws {
        let app = XCUIApplication.roadivo(skipOnboarding: true, pro: true, carConnected: true)
        app.tabBars.buttons["Settings"].tap()
        app.buttons["settings.displayProfiles"].tap()
        let save = app.buttons["profiles.saveCurrent"]
        XCTAssertTrue(save.waitForExistence(timeout: 10))
        save.tap()

        let fill = app.buttons["Fill"]
        XCTAssertTrue(fill.waitForExistence(timeout: 5))
        fill.tap()
        XCTAssertTrue(fill.isSelected)
        let playsNext = app.switches["profile.playsNext"]
        XCTAssertEqual(playsNext.value as? String, "1")
        playsNext.switches.firstMatch.tap()
        XCTAssertEqual(playsNext.value as? String, "0")
        XCTAssertTrue(app.switches["profile.carMode"].isEnabled)
        snapshot("41-Profile-Editor", app: app)
        try auditIgnoringBottomEdge(app, for: [.dynamicType, .sufficientElementDescription, .hitRegion])

        app.navigationBars.buttons.element(boundBy: 0).tap()
        let row = app.buttons["profiles.row.CarPlay"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(app.buttons["Fill"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Fill"].isSelected)
        XCTAssertEqual(app.switches["profile.playsNext"].value as? String, "0")
    }

    func testSettingsListsThisIPhoneAndSavedProfiles() throws {
        let app = XCUIApplication.roadivo(skipOnboarding: true, carConnected: true)
        app.tabBars.buttons.element(boundBy: 4).tap()
        app.buttons["settings.displayProfiles"].tap()
        let save = app.buttons["profiles.saveCurrent"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["profiles.thisIPhone"].exists)
        snapshot("42-Display-Profiles", app: app)
        try auditIgnoringBottomEdge(app, for: [.dynamicType, .sufficientElementDescription, .hitRegion])

        save.tap()
        // Free: Car Mode on connect is shown but locked, as Car Mode is a Pro feature.
        let carMode = app.switches["profile.carMode"]
        XCTAssertTrue(carMode.waitForExistence(timeout: 5))
        XCTAssertFalse(carMode.isEnabled)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["profiles.row.CarPlay"].waitForExistence(timeout: 5))
        XCTAssertFalse(save.exists)

        // This iPhone has the picture, playback and subtitles, but nothing tied to a receiver.
        app.buttons["profiles.thisIPhone"].tap()
        XCTAssertTrue(app.buttons["Fit"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.switches["profile.playsNext"].exists)
        XCTAssertFalse(app.switches["profile.carMode"].exists)
        XCTAssertFalse(app.buttons["profile.delete"].exists)
    }
}
