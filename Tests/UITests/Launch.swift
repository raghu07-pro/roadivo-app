import XCTest

extension XCUIApplication {
    /// Launches with in-memory storage and a fake App Store so every UI test
    /// starts clean. `skipOnboarding` also skips the intro paywall.
    static func roadivo(skipOnboarding: Bool = false, demoLibrary: Bool = false, pro: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        if skipOnboarding {
            app.launchArguments.append("-skip-onboarding")
        }
        if demoLibrary {
            app.launchArguments.append("-demo-library")
        }
        if pro {
            app.launchArguments.append("-pro")
        }
        app.launch()
        return app
    }
}

extension XCTestCase {
    /// Waits until `element` is fully on screen and has stopped moving, so a
    /// screenshot never catches a page mid-swipe.
    func waitUntilSettled(_ element: XCUIElement, in app: XCUIApplication, timeout: TimeInterval = 5) {
        let screen = app.windows.firstMatch.frame
        let deadline = Date().addingTimeInterval(timeout)
        var last = CGRect.null
        while Date() < deadline {
            let frame = element.exists ? element.frame : .null
            if !frame.isNull, screen.contains(frame), frame == last {
                return
            }
            last = frame
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        XCTFail("\(element) did not settle on screen")
    }

    /// Attaches a named screenshot (and, under fastlane, is where `snapshot()` hooks in).
    func snapshot(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
