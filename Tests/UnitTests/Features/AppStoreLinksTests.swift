import Foundation
import Testing
@testable import Roadivo

@Suite("App Store links")
struct AppStoreLinksTests {
    @Test("A numeric App Store ID gives the listing and the write-review deep link")
    func numericID() {
        let links = AppStoreLinks(appStoreID: "6741234567")
        #expect(links.page?.absoluteString == "https://apps.apple.com/app/id6741234567")
        #expect(links.writeReview?.absoluteString == "https://apps.apple.com/app/id6741234567?action=write-review")
    }

    @Test(
        "No usable ID gives no links, so Settings falls back",
        arguments: [nil, "", "  ", "$(APP_STORE_ID)", "id123", "12a4"]
    )
    func noID(value: String?) {
        let links = AppStoreLinks(appStoreID: value)
        #expect(links.page == nil)
        #expect(links.writeReview == nil)
    }

    @Test("The shipped build has no ID until the App Store Connect record exists")
    func currentBuild() {
        // Flip this expectation when APP_STORE_ID is set in Config/Shared.xcconfig.
        #expect(AppStoreLinks.current.page == nil)
    }
}
