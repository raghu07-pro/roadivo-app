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

    @Test("Debug browsing requires Pro without relying on parking or location")
    func browserAccess() {
        #if DEBUG
            #expect(CarBrowserAccess.isAllowed(isPro: true))
        #else
            #expect(!CarBrowserAccess.isAllowed(isPro: true))
        #endif
        #expect(!CarBrowserAccess.isAllowed(isPro: false))
    }

    @Test("Switching tabs keeps each document, zoom, and page state independent")
    func separateTabs() throws {
        let car = CarBrowserController()
        car.page.loader = { _, _ in }
        car.open(try #require(URL(string: "https://first.example.com")))
        car.setAllowed(true)
        let first = car.session.selected
        let firstURL = try #require(URL(string: "https://first.example.com/article"))
        first.page.onState?(WebPageController.State(url: firstURL, title: "First"))
        car.setPageZoom(1.5)

        #expect(car.newTab())
        let second = car.session.selected
        #expect(first.page.webView !== second.page.webView)
        let store = first.page.webView.configuration.websiteDataStore
        #expect(store === second.page.webView.configuration.websiteDataStore)
        #expect(car.state.url == nil)
        #expect(second.zoom == 1)
        first.page.onState?(WebPageController.State(url: firstURL, title: "Updated first"))
        #expect(car.state.title.isEmpty)

        car.selectTab(first.id)
        #expect(car.state.title == "Updated first")
        #expect(car.page.webView.pageZoom == 1.5)
        car.closeTab()
        #expect(car.session.selected === second)
        #expect(car.session.tabs.count == 1)
    }

    @Test("Car tabs are bounded and closing the browser clears all session data")
    func tabLimitAndSessionCleanup() throws {
        let car = CarBrowserController()
        car.page.loader = { _, _ in }
        car.open(try #require(URL(string: "https://example.com")))
        car.setAllowed(true)
        car.page.onState?(WebPageController.State(url: URL(string: "https://example.com"), title: "Example"))
        car.session.toggleSavedPage()
        #expect(car.session.savedPages.count == 1)
        for _ in 1..<CarBrowserSession.maximumTabs { #expect(car.newTab()) }
        #expect(car.session.tabs.count == CarBrowserSession.maximumTabs)
        #expect(!car.newTab())
        car.close()
        #expect(car.session.tabs.count == 1)
        #expect(car.session.savedPages.isEmpty)
        #expect(car.state.url == nil)
        #expect(!car.isOpen)
    }

    @Test("YouTube search preserves punctuation and Unicode without adding URL parameters")
    func youtubeSearchEncoding() throws {
        let query = "music & science + తెలుగు? #1"
        let url = try #require(CarBrowserSiteSearch.url(for: query, on: URL(string: "https://www.youtube.com")))
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.host == "m.youtube.com")
        #expect(components.path == "/results")
        #expect(components.queryItems == [URLQueryItem(name: "search_query", value: query)])
        #expect(CarBrowserSiteSearch.url(for: " ", on: url) == nil)
        #expect(CarBrowserSiteSearch.url(for: query, on: URL(string: "https://youtube.com.example.org")) == nil)
    }
}
