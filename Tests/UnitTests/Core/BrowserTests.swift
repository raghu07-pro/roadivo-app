import Foundation
import Testing
@testable import Roadivo

@Suite("Browser addresses and videos")
struct WebAddressTests {
    @Test(
        "Addresses open as typed, bare sites get https, home servers http",
        arguments: [
            ("https://example.com/a?b=1", "https://example.com/a?b=1"),
            ("http://tv.example.com", "http://tv.example.com"),
            ("example.com", "https://example.com"),
            ("www.apple.com/tv", "https://www.apple.com/tv"),
            ("192.168.1.10:8096", "http://192.168.1.10:8096"),
            ("nas.local/web", "http://nas.local/web"),
            ("  example.org  ", "https://example.org")
        ]
    )
    func addresses(input: String, expected: String) {
        #expect(WebAddress.url(for: input)?.absoluteString == expected)
    }

    @Test("Words, a bare name and a file name are searched", arguments: ["road trip movies", "roadivo", "clip.mp4"])
    func searches(input: String) throws {
        let url = try #require(WebAddress.url(for: input))
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "q" }
        #expect(url.absoluteString.hasPrefix(WebAddress.searchEngine))
        #expect(query?.value == input)
    }

    @Test("Nothing typed opens nothing")
    func empty() {
        #expect(WebAddress.url(for: "   ") == nil)
    }

    @Test("Lists name a page by its site, without www")
    func displayName() throws {
        #expect(try WebAddress.displayName(of: #require(URL(string: "https://www.example.com/a/b"))) == "example.com")
        #expect(try WebAddress.displayName(of: #require(URL(string: "http://192.168.1.10:8096/web"))) == "192.168.1.10")
    }

    @Test("A page is a video Roadivo can play by its type or its file name, never a channel list")
    func playablePages() throws {
        let stream = try #require(URL(string: "https://cdn.example.com/live/master.m3u8"))
        let file = try #require(URL(string: "https://cdn.example.com/films/trip.mp4?token=1"))
        let unnamed = try #require(URL(string: "https://cdn.example.com/watch?id=7"))
        let channels = try #require(URL(string: "https://provider.example.com/get.m3u"))
        let page = try #require(URL(string: "https://example.com/"))

        #expect(WebMedia.isPlayablePage(stream, mimeType: nil))
        #expect(WebMedia.isPlayablePage(file, mimeType: "application/octet-stream"))
        #expect(WebMedia.isPlayablePage(unnamed, mimeType: "application/vnd.apple.mpegurl"))
        #expect(WebMedia.isPlayablePage(unnamed, mimeType: "video/mp4"))
        #expect(!WebMedia.isPlayablePage(channels, mimeType: "audio/x-mpegurl"))
        #expect(!WebMedia.isPlayablePage(page, mimeType: "text/html"))
        #expect(!WebMedia.isPlayablePage(unnamed, mimeType: "video/webm")) // AVPlayer can't play it.
    }

    @Test("A video a page started plays in Roadivo unless the page assembles it itself")
    func playableSources() throws {
        #expect(try WebMedia.isPlayableSource(#require(URL(string: "https://cdn.example.com/v?id=1"))))
        #expect(!WebMedia.isPlayableSource(URL(string: "blob:https://example.com/5f2c")))
        #expect(!WebMedia.isPlayableSource(URL(string: "https://provider.example.com/list.m3u")))
    }
}

@Suite("CarPlay Browser search")
struct BrowserSearchTests {
    private let sites = Array(BrowserSite.all.prefix(5))

    @Test("Nothing typed lists the sites")
    func emptyListsSites() {
        #expect(BrowserSearch.results(for: "  ", sites: sites, limit: 12) == sites.map(BrowserSearch.Result.site))
    }

    @Test("A typed address comes first, then a web search for it")
    func addressThenSearch() throws {
        let results = BrowserSearch.results(for: "example.com", sites: sites, limit: 12)
        #expect(try results.first == .address(#require(URL(string: "https://example.com"))))
        guard case let .search(query, url) = results.last else {
            Issue.record("No web search row")
            return
        }
        #expect(query == "example.com")
        #expect(url.absoluteString.hasPrefix(WebAddress.searchEngine))
        #expect(results.count == 2)
    }

    @Test("Words match sites by name or address, then a web search; a site's own address shows as the site")
    func wordsMatchSites() throws {
        let youtube = try #require(sites.first { $0.name == "YouTube" })
        #expect(BrowserSearch.results(for: "tube", sites: sites, limit: 12).first == .site(youtube))
        let typed = BrowserSearch.results(for: "m.youtube.com", sites: sites, limit: 12)
        #expect(typed.first == .site(youtube))
        #expect(!typed.contains {
            if case .address = $0 {
                true
            } else {
                false
            }
        })
    }

    @Test("A short list keeps the web search as its last row")
    func limitKeepsSearch() {
        let results = BrowserSearch.results(for: "o", sites: BrowserSite.all, limit: 3)
        #expect(results.count == 3)
        guard case .search = results.last else {
            Issue.record("The web search was cut")
            return
        }
    }
}
