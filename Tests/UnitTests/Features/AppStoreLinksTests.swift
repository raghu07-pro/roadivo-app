import Foundation
import Testing
@testable import PlayCarTV

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

    @Test("The shipped build links to PlayCarTV's App Store listing")
    func currentBuild() {
        // APP_STORE_ID in Config/Shared.xcconfig: the App Store Connect record's Apple ID.
        #expect(AppStoreLinks.current.page?.absoluteString == "https://apps.apple.com/app/id6824396756")
    }
}
