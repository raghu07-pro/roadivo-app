import CarPlay
import Foundation
import Testing
import WebKit
@testable import Roadivo

@Suite("Independent car browser")
@MainActor
struct CarBrowserTests {
    @Test("Selecting a CarPlay search result uses the car callback and completes the template action")
    func searchRoutesToCar() throws {
        let url = try #require(URL(string: "https://example.com/article"))
        var opened: URL?
        var completed = false
        let tab = CarPlayBrowserTab(
            interfaceController: nil, markAsVideo: { _ in false }, openPage: { opened = $0 }
        )
        let item = CPListItem(text: "Article", detailText: nil)
        item.userInfo = url
        tab.searchTemplate(CPSearchTemplate(), selectedResult: item) { completed = true }
        #expect(opened == url)
        #expect(completed)
    }

    @Test("Car navigation never loads a URL or changes state in the phone browser")
    func independentNavigation() throws {
        let phone = BrowserViewModel()
        var phoneLoads: [URL] = []
        phone.web.loader = { _, url in phoneLoads.append(url) }
        phone.open("https://phone.example.com/article")
        let car = CarBrowserController()
        var carLoads: [URL] = []
        car.page.loader = { _, url in carLoads.append(url) }
        let carURL = try #require(URL(string: "https://car.example.com/news"))

        car.open(carURL)
        #expect(carLoads.isEmpty)
        car.setAllowed(true)

        #expect(carLoads == [carURL])
        #expect(phoneLoads.count == 1)
        #expect(phone.pageURL?.host() == "phone.example.com")
        #expect(car.page.webView !== phone.web.webView)
        #expect(!car.page.webView.configuration.websiteDataStore.isPersistent)
        #expect(phone.web.webView.configuration.websiteDataStore.isPersistent)
        #expect(car.page.webView.configuration.defaultWebpagePreferences.preferredContentMode == .mobile)
    }

    @Test("Closing cancels a queued URL and late page reports cannot restore the session")
    func closeDropsPendingNavigation() throws {
        let car = CarBrowserController()
        var loads = 0
        car.page.loader = { _, _ in loads += 1 }
        car.open(try #require(URL(string: "https://example.com")))
        car.close()
        car.page.onState?(WebPageController.State(url: URL(string: "https://late.example.com")))
        car.setAllowed(true)
        #expect(!car.isOpen)
        #expect(car.state.url == nil)
        #expect(loads == 0)
    }

    @Test("Native link selection rejects app and script URLs, deduplicates, and keeps full destinations")
    func linkSelection() {
        let links = CarBrowserLink.parse([
            ["title": " Article ", "url": "https://example.com/article?q=a#section"],
            ["title": "Duplicate", "url": "https://example.com/article?q=a#section"],
            ["title": "Script", "url": "javascript:alert(1)"],
            ["title": "Mail", "url": "mailto:a@example.com"],
            ["title": "File", "url": "file:///private/data"],
            ["title": " ", "url": "https://www.example.org/other"]
        ])
        #expect(links.map(\.title) == ["Article", "example.org"])
        #expect(links.first?.url.absoluteString == "https://example.com/article?q=a#section")
    }

    @Test("Keyboard availability alone never authorizes browsing; readings must be still and fresh")
    func accessRequiresEvidence() {
        let now = Date(timeIntervalSince1970: 100)
        func allowed(
            pro: Bool = true, parked: Bool = true, denied: Bool = false,
            sample: MotionSample? = .still, age: TimeInterval? = 0
        ) -> Bool {
            CarBrowserAccess.isAllowed(
                isPro: pro, isParked: parked, isLocationDenied: denied, sample: sample,
                sampledAt: age.map { now.addingTimeInterval(-$0) }, now: now
            )
        }
        #expect(allowed())
        #expect(allowed(age: 10))
        #expect(!allowed(age: 10.1))
        #expect(!allowed(age: -1))
        #expect(!allowed(age: nil))
        #expect(!allowed(sample: nil))
        #expect(!allowed(sample: .unknown))
        #expect(!allowed(sample: .moving))
        #expect(!allowed(pro: false))
        #expect(!allowed(parked: false))
        #expect(!allowed(denied: true))
    }
}
