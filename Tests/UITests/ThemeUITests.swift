import XCTest

@MainActor
final class ThemeUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func openTheme(_ app: XCUIApplication) {
        app.settingsTab.tap()
        let row = app.buttons["settings.theme"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        let system = app.buttons["theme.appearance.system"]
        XCTAssertTrue(system.waitForExistence(timeout: 5))
        waitUntilSettled(system, in: app) // An audit mid-push reports text "clipped" by the slide.
    }

    /// Each launch under -ui-testing starts from System + Golden Hour.
    func testThemeStartsFromTheDefaults() {
        let app = XCUIApplication.playcartv(skipOnboarding: true)
        openTheme(app)
        XCTAssertTrue(app.buttons["theme.appearance.system"].isSelected)
        XCTAssertTrue(app.buttons["theme.accent.golden"].isSelected)
    }

    /// Picking an appearance selects it alone, and stays picked after leaving
    /// the screen.
    func testChoosingDarkSelectsIt() {
        let app = XCUIApplication.playcartv(skipOnboarding: true)
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
        let app = XCUIApplication.playcartv(skipOnboarding: true)
        openTheme(app)
        let startsDark = try backgroundIsDark(app)

        app.buttons["theme.appearance.dark"].tap()
        XCTAssertTrue(try waitForBackground(dark: true, in: app), "Dark didn't darken the screen")

        app.buttons["theme.appearance.system"].tap()
        XCTAssertTrue(try waitForBackground(dark: startsDark, in: app), "System didn't restore the iPhone's appearance")
    }

    /// Every accent can be picked, and only one is ever selected.
    func testChoosingEachAccentSelectsOnlyIt() {
        let app = XCUIApplication.playcartv(skipOnboarding: true)
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

    func testChoosingEachFontStyleSelectsOnlyIt() {
        let app = XCUIApplication.playcartv(skipOnboarding: true)
        openTheme(app)
        app.swipeUp() // Font Style sits below the accents.
        let fonts = ["roadSign", "standard", "rounded", "serif"]
        XCTAssertTrue(app.buttons["theme.font.roadSign"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["theme.font.roadSign"].isSelected)
        for font in fonts {
            let option = app.buttons["theme.font.\(font)"]
            option.tap()
            XCTAssertTrue(option.isSelected, font)
            for other in fonts where other != font {
                XCTAssertFalse(app.buttons["theme.font.\(other)"].isSelected, "\(other) still selected")
            }
        }
        app.buttons["theme.font.rounded"].tap()
        snapshot("36-Theme-Font-Rounded", app: app)
        // The whole app follows: Home's text and the tab labels too.
        app.tabBars.buttons.element(boundBy: 0).tap()
        snapshot("37-Home-Font-Rounded", app: app)
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
        let app = XCUIApplication.playcartv(skipOnboarding: true)
        openTheme(app)
        try audit(app)
        app.buttons["theme.appearance.dark"].tap()
        XCTAssertTrue(app.buttons["theme.appearance.dark"].isSelected)
        try audit(app)
    }

    func testSettingsAccessibilityAudit() throws {
        let app = XCUIApplication.playcartv(skipOnboarding: true)
        app.settingsTab.tap()
        let theme = app.buttons["settings.theme"]
        XCTAssertTrue(theme.waitForExistence(timeout: 5))
        waitUntilSettled(theme, in: app)
        // Enlarged in place, the Media section's third row slides below the screen. Moved up a row, the
        // flag passed to the row that took its place, so it's the position, not the text (2026-10-16).
        try audit(app, alsoIgnoring: ["Car & Display Profiles", "Aspect ratio · Subtitles · Playback"])
    }

    /// All audits but contrast: it can't name text under the glass bars; `ThemeTests` checks WCAG.
    private func audit(_ app: XCUIApplication, alsoIgnoring labels: Set<String> = []) throws {
        try auditIgnoringBottomEdge(
            app,
            for: XCUIAccessibilityAuditType.all.subtracting(.contrast),
            alsoIgnoring: labels
        )
    }
}
