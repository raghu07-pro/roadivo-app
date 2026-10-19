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
