import XCTest

@MainActor
final class OnboardingFlowUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// The first-launch flow: 4 onboarding pages → Buy a plan → close → Home.
    func testFirstLaunchFlowEndsOnHome() {
        let app = XCUIApplication.roadivo()
        let continueButton = app.buttons["onboarding.continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
        for _ in 0..<4 {
            continueButton.tap()
        }

        let close = app.buttons["paywall.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["paywall.plan.lifetime"].waitForExistence(timeout: 5))
        close.tap()

        XCTAssertTrue(app.buttons["library.empty.addSource"].waitForExistence(timeout: 5))
    }

    func testBuyingOnTheIntroPaywallUnlocksPro() {
        let app = XCUIApplication.roadivo()
        XCTAssertTrue(app.buttons["onboarding.skip"].waitForExistence(timeout: 5))
        app.buttons["onboarding.skip"].tap()
        let buy = app.buttons["paywall.buy"]
        XCTAssertTrue(app.buttons["paywall.plan.yearly"].waitForExistence(timeout: 5))
        app.buttons["paywall.plan.yearly"].tap()
        buy.tap()
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Settings"].tap()
        // The upgrade banner gives way to the active plan's.
        XCTAssertTrue(app.buttons["settings.plan"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["settings.pro"].exists)
    }

    /// First launch: Restore brings back an earlier purchase, closes the paywall onto Home, and
    /// Settings then names the plan.
    func testRestoreOnTheIntroPaywallUnlocksPro() {
        let app = XCUIApplication.roadivo(restorable: true)
        XCTAssertTrue(app.buttons["onboarding.skip"].waitForExistence(timeout: 5))
        app.buttons["onboarding.skip"].tap()
        let restore = app.buttons["paywall.restore"]
        XCTAssertTrue(restore.waitForExistence(timeout: 5))
        restore.tap()
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.buttons["settings.plan"].waitForExistence(timeout: 5))
    }

    /// From Settings: Restore closes the paywall onto Home, with the plan active.
    func testRestoreFromSettingsGoesHome() {
        let app = XCUIApplication.roadivo(skipOnboarding: true, restorable: true)
        app.tabBars.buttons["Settings"].tap()
        let upgrade = app.buttons["settings.pro"]
        XCTAssertTrue(upgrade.waitForExistence(timeout: 5))
        upgrade.tap()
        let restore = app.buttons["paywall.restore"]
        XCTAssertTrue(restore.waitForExistence(timeout: 5))
        restore.tap()
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.buttons["settings.plan"].waitForExistence(timeout: 5))
    }

    /// A subscriber opening the plans sees theirs selected and can't buy it again.
    func testPaywallOpensOnTheCurrentPlan() {
        let app = XCUIApplication.roadivo(skipOnboarding: true, pro: true) // The fake Pro user has Yearly.
        app.tabBars.buttons["Settings"].tap()
        let plan = app.buttons["settings.plan"]
        XCTAssertTrue(plan.waitForExistence(timeout: 5))
        plan.tap()
        let yearly = app.buttons["paywall.plan.yearly"]
        XCTAssertTrue(yearly.waitForExistence(timeout: 5))
        XCTAssertTrue(yearly.isSelected)
        XCTAssertFalse(app.buttons["paywall.plan.lifetime"].isSelected)
        XCTAssertFalse(app.buttons["paywall.buy"].isEnabled)
    }

    /// Nothing to restore: the paywall stays and says so.
    func testRestoreWithNothingBoughtSaysSo() {
        let app = XCUIApplication.roadivo()
        XCTAssertTrue(app.buttons["onboarding.skip"].waitForExistence(timeout: 5))
        app.buttons["onboarding.skip"].tap()
        let restore = app.buttons["paywall.restore"]
        XCTAssertTrue(restore.waitForExistence(timeout: 5))
        restore.tap()
        XCTAssertTrue(app.staticTexts["paywall.message"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["paywall.close"].exists)
    }

    func testSkipGoesToThePaywall() {
        let app = XCUIApplication.roadivo()
        let skip = app.buttons["onboarding.skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 5))
        skip.tap()
        XCTAssertTrue(app.buttons["paywall.close"].waitForExistence(timeout: 5))
    }

    func testOnboardingAccessibilityAudit() throws {
        let app = XCUIApplication.roadivo()
        XCTAssertTrue(app.buttons["onboarding.continue"].waitForExistence(timeout: 5))
        // The system page indicator is outside our control; contrast is checked
        // separately in the light and dark snapshots.
        try app.performAccessibilityAudit(for: [.dynamicType, .sufficientElementDescription, .hitRegion])
    }

    func testPaywallAccessibilityAudit() throws {
        let app = XCUIApplication.roadivo()
        app.buttons["onboarding.skip"].tap()
        XCTAssertTrue(app.buttons["paywall.plan.lifetime"].waitForExistence(timeout: 5))
        try app.performAccessibilityAudit(for: [.sufficientElementDescription, .hitRegion])
    }
}

@MainActor
final class LocalizationUITests: XCTestCase {
    /// Launches in German: the onboarding and paywall must come up translated.
    func testGermanFirstLaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        app.launch()
        let next = app.buttons["onboarding.continue"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        XCTAssertEqual(next.label, "Weiter")
        snapshot("25-German-Onboarding", app: app)
        app.buttons["onboarding.skip"].tap()
        XCTAssertTrue(app.buttons["paywall.plan.lifetime"].waitForExistence(timeout: 5))
        snapshot("26-German-Paywall", app: app)
    }
}

@MainActor
final class LanguageSwitchUITests: XCTestCase {
    /// Picking a language in Settings changes the app at once, no relaunch.
    func testChoosingGermanSwitchesImmediately() {
        let app = XCUIApplication.roadivo(skipOnboarding: true)
        app.tabBars.buttons["Settings"].tap()
        app.buttons["settings.language"].tap()
        let german = app.buttons["language.de"]
        XCTAssertTrue(german.waitForExistence(timeout: 5))
        german.tap()
        // The tab bar redraws in German straight away.
        XCTAssertTrue(app.tabBars.buttons["Einstellungen"].waitForExistence(timeout: 5))
        snapshot("27-Language-Switched", app: app)
        // And back to the system language.
        app.tabBars.buttons["Einstellungen"].tap()
        app.buttons["settings.language"].tap()
        app.buttons["language.system"].tap()
        XCTAssertTrue(app.tabBars.buttons["Settings"].waitForExistence(timeout: 5))
    }
}
