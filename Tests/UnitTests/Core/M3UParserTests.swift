import Foundation
import Testing
@testable import PlayCarTV

@Suite("M3U parser")
struct M3UParserTests {
    @Test("Reads names, groups, logos and URLs in order")
    func parsesExtendedM3U() throws {
        let entries = M3UParser.parse(Fixtures.playlist)
        #expect(entries.count == 4)
        let first = try #require(entries.first)
        #expect(first.name == "News One")
        #expect(first.group == "News")
        #expect(first.logoURL?.absoluteString == "https://logos.example.com/news1.png")
        #expect(first.streamURL.absoluteString == "https://streams.example.com/news1.m3u8")
        #expect(entries.map(\.group) == ["News", "News", "Sports", ""])
    }

    @Test("Tolerates a byte-order mark and CRLF line endings")
    func bomAndCRLF() throws {
        let text = "\u{FEFF}#EXTM3U\r\n#EXTINF:-1 group-title=\"A\",One\r\nhttp://a.example.com/1.ts\r\n"
        #expect(try M3UParser.parse(text) == [
            PlaylistEntry(
                name: "One",
                group: "A",
                logoURL: nil,
                streamURL: #require(URL(string: "http://a.example.com/1.ts"))
            )
        ])
    }

    @Test("Works without the #EXTM3U header and names bare URLs from the path")
    func bareURLs() {
        #expect(M3UParser.parse("https://cdn.example.com/films/coastal-echoes.mp4\n").map(\.name) == ["coastal-echoes"])
    }

    @Test("A comma inside a quoted attribute does not end the attributes")
    func quotedComma() {
        let text = "#EXTINF:-1 group-title=\"Movies, Classics\" tvg-logo=\"x.png\",The Film\nhttp://e.com/f.mp4"
        let entry = M3UParser.parse(text, baseURL: URL(string: "http://e.com/list.m3u"))
        #expect(entry.first?.group == "Movies, Classics")
        #expect(entry.first?.name == "The Film")
        #expect(entry.first?.logoURL?.absoluteString == "http://e.com/x.png")
    }

    @Test("#EXTGRP sets the group when group-title is missing")
    func extgrp() {
        #expect(M3UParser.parse("#EXTINF:-1,Radio\n#EXTGRP:Music\nhttp://e.com/radio.aac").first?.group == "Music")
    }

    @Test("Relative stream URLs resolve against the playlist URL")
    func relativeURLs() {
        let base = URL(string: "https://e.com/lists/main.m3u")
        let entries = M3UParser.parse("#EXTINF:-1,Local\nstreams/one.m3u8", baseURL: base)
        #expect(entries.first?.streamURL.absoluteString == "https://e.com/lists/streams/one.m3u8")
    }

    @Test("Lines that aren't playable URLs are skipped, not fatal")
    func skipsJunk() {
        let text = """
        #EXTINF:-1,Broken
        not a url
        #EXTVLCOPT:http-user-agent=VLC
        #EXTINF:-1,Good
        https://e.com/good.m3u8
        mailto:someone@example.com
        """
        #expect(M3UParser.parse(text).map(\.name) == ["Good"])
    }

    @Test("A sign-in page yields no channels, even resolved against the playlist's URL")
    func signInPageYieldsNothing() throws {
        let base = try #require(URL(string: "http://iptv.example.com/get.php?username=me&password=old"))
        #expect(M3UParser.parse(Fixtures.signInPage, baseURL: base).isEmpty)
    }

    @Test("A plain-text error reply yields no channels")
    func plainTextReplyYieldsNothing() throws {
        let base = try #require(URL(string: "http://iptv.example.com/get.php"))
        #expect(M3UParser.parse("Unauthorized\nAccount expired\n", baseURL: base).isEmpty)
    }

    @Test("Relative lines resolve once the text declares itself an extended M3U")
    func relativeNeedsExtendedHeader() throws {
        let base = try #require(URL(string: "https://e.com/lists/main.m3u"))
        #expect(M3UParser.parse("#EXTM3U\nstreams/one.m3u8", baseURL: base).map(\.streamURL.absoluteString) == [
            "https://e.com/lists/streams/one.m3u8"
        ])
        #expect(M3UParser.parse("streams/one.m3u8", baseURL: base).isEmpty)
    }

    @Test("Links to files on the device are skipped")
    func skipsFileURLs() {
        let text = "#EXTM3U\n#EXTINF:-1,Secret\nfile:///etc/passwd\n#EXTINF:-1,Good\nhttps://e.com/good.m3u8"
        #expect(M3UParser.parse(text).map(\.name) == ["Good"])
    }

    @Test("Web pages, XML and JSON replies are recognised; playlists are not")
    func recognisesWebPages() {
        #expect(M3UParser.looksLikeWebPage(Fixtures.signInPage))
        #expect(M3UParser.looksLikeWebPage("\u{FEFF}  \n<?xml version=\"1.0\"?><tv></tv>"))
        #expect(M3UParser.looksLikeWebPage(#"{"user_info":{"auth":0}}"#))
        #expect(!M3UParser.looksLikeWebPage(Fixtures.playlist))
        #expect(!M3UParser.looksLikeWebPage("https://cdn.example.com/films/coastal-echoes.mp4"))
    }

    @Test("tvg-name is used when the title after the comma is empty")
    func tvgNameFallback() {
        #expect(M3UParser.parse("#EXTINF:-1 tvg-name=\"Channel 5\",\nhttp://e.com/5.ts").first?.name == "Channel 5")
    }

    @Test("Recognises an HLS stream as a single stream, not a channel list")
    func detectsHLS() {
        #expect(M3UParser.isHLSStream(Fixtures.hlsStream))
        #expect(!M3UParser.isHLSStream(Fixtures.playlist))
    }

    @Test("An empty or header-only file yields no entries")
    func empty() {
        #expect(M3UParser.parse("").isEmpty)
        #expect(M3UParser.parse("#EXTM3U\n").isEmpty)
    }
}
