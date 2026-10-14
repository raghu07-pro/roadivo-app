import XCTest

@MainActor
final class ThemeUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func openTheme(_ app: XCUIApplication) {
        app.tabBars.buttons.element(boundBy: 3).tap()
        let row = app.buttons["settings.theme"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(app.buttons["theme.appearance.system"].waitForExistence(timeout: 5))
    }

    /// Each launch under -ui-testing starts from System + Golden Hour.
    func testThemeStartsFromTheDefaults() {
        let app = XCUIApplication.roadivo(skipOnboarding: true)
        openTheme(app)
        XCTAssertTrue(app.buttons["theme.appearance.system"].isSelected)
        XCTAssertTrue(app.buttons["theme.accent.golden"].isSelected)
    }

    /// Picking an appearance selects it alone, and stays picked after leaving
    /// the screen.
    func testChoosingDarkSelectsIt() {
        let app = XCUIApplication.roadivo(skipOnboarding: true)
        openTheme(app)
        app.buttons["theme.appearance.dark"].tap()
        XCTAssertTrue(app.buttons["theme.appearance.dark"].isSelected)
        XCTAssertFalse(app.buttons["theme.appearance.system"].isSelected)
        snapshot("28-Theme-Dark", app: app)

        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["settings.theme"].tap()
        XCTAssertTrue(app.buttons["theme.appearance.dark"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["theme.appearance.dark"].isSelected)

        app.buttons["theme.appearance.light"].tap()
        XCTAssertTrue(app.buttons["theme.appearance.light"].isSelected)
        XCTAssertFalse(app.buttons["theme.appearance.dark"].isSelected)
    }

    /// Dark really darkens the screen, and System hands it back to the
    /// iPhone's setting (the simulator runs in Light) without a relaunch.
    func testDarkThenSystemFollowsTheIPhoneAgain() throws {
        let app = XCUIApplication.roadivo(skipOnboarding: true)
        openTheme(app)
        let startsDark = try backgroundIsDark(app)

        app.buttons["theme.appearance.dark"].tap()
        XCTAssertTrue(try waitForBackground(dark: true, in: app), "Dark didn't darken the screen")

        app.buttons["theme.appearance.system"].tap()
        XCTAssertTrue(try waitForBackground(dark: startsDark, in: app), "System didn't restore the iPhone's appearance")
    }

    /// Every accent can be picked, and only one is ever selected.
    func testChoosingEachAccentSelectsOnlyIt() {
        let app = XCUIApplication.roadivo(skipOnboarding: true)
        openTheme(app)
        let accents = ["sunset", "ocean", "twilight", "rose", "golden", "graphite"]
        for accent in accents {
            let swatch = app.buttons["theme.accent.\(accent)"]
            swatch.tap()
            XCTAssertTrue(swatch.isSelected, accent)
            for other in accents where other != accent {
                XCTAssertFalse(app.buttons["theme.accent.\(other)"].isSelected, "\(other) still selected")
            }
        }
        app.buttons["theme.accent.ocean"].tap()
        snapshot("29-Theme-Ocean", app: app)
    }

    /// Samples the screen background in the left margin, beside the content.
    private func backgroundIsDark(_ app: XCUIApplication) throws -> Bool {
        let image = app.screenshot().image
        let cgImage = try XCTUnwrap(image.cgImage)
        let pointX = Int(4 * image.scale)
        let pointY = Int(image.size.height * 0.6 * image.scale)
        let context = try XCTUnwrap(CGContext(
            data: nil,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        let pixel = try XCTUnwrap(cgImage.cropping(to: CGRect(x: pointX, y: pointY, width: 1, height: 1)))
        context.draw(pixel, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        let bytes = try XCTUnwrap(context.data?.assumingMemoryBound(to: UInt8.self))
        let brightness = (Int(bytes[0]) + Int(bytes[1]) + Int(bytes[2])) / 3
        return brightness < 128
    }

    private func waitForBackground(dark: Bool, in app: XCUIApplication) throws -> Bool {
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            if try backgroundIsDark(app) == dark {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        return false
    }

    func testThemeAccessibilityAuditLightAndDark() throws {
        let app = XCUIApplication.roadivo(skipOnboarding: true)
        openTheme(app)
        try audit(app)
        app.buttons["theme.appearance.dark"].tap()
        XCTAssertTrue(app.buttons["theme.appearance.dark"].isSelected)
        try audit(app)
    }

    func testSettingsAccessibilityAudit() throws {
        let app = XCUIApplication.roadivo(skipOnboarding: true)
        app.tabBars.buttons.element(boundBy: 3).tap()
        let theme = app.buttons["settings.theme"]
        XCTAssertTrue(theme.waitForExistence(timeout: 5))
        waitUntilSettled(theme, in: app)
        try audit(app)
    }

    /// All audits but contrast (it can't name text under the glass bars; `ThemeTests` checks WCAG),
    /// ignoring Dynamic Type findings just above the tab bar, where enlarged text slides under it.
    private func audit(_ app: XCUIApplication) throws {
        let tabBar = app.tabBars.firstMatch.exists ? app.tabBars.firstMatch.frame : .null
        try app.performAccessibilityAudit(for: XCUIAccessibilityAuditType.all.subtracting(.contrast)) { issue in
            guard issue.auditType == .dynamicType, let element = issue.element, !tabBar.isNull else { return false }
            return element.frame.maxY > tabBar.minY - 180
        }
    }
}
