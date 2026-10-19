import Foundation
import Network
import Testing
@testable import Roadivo

@Suite("Screen Broadcast server")
struct BroadcastHTTPTests {
    private func request(_ line: String) -> Data {
        Data("\(line)\r\nHost: 172.20.10.1:8080\r\nAccept: */*\r\n\r\n".utf8)
    }

    @Test("Only this install's code reaches the page and the stream; anything else is not found")
    func routes() {
        let code = "k7m2qp"
        #expect(BroadcastHTTP.route(for: request("GET /k7m2qp HTTP/1.1"), code: code) == .page)
        #expect(BroadcastHTTP.route(for: request("GET /k7m2qp/ HTTP/1.1"), code: code) == .page)
        #expect(BroadcastHTTP.route(for: request("GET /k7m2qp/stream?1760870400 HTTP/1.1"), code: code) == .stream)
        #expect(BroadcastHTTP.route(for: request("GET / HTTP/1.1"), code: code) == .notFound)
        #expect(BroadcastHTTP.route(for: request("GET /stream HTTP/1.1"), code: code) == .notFound)
        #expect(BroadcastHTTP.route(for: request("GET /abcdef/stream HTTP/1.1"), code: code) == .notFound)
        #expect(BroadcastHTTP.route(for: request("POST /k7m2qp/stream HTTP/1.1"), code: code) == .notFound)
        #expect(BroadcastHTTP.route(for: Data([0xFF, 0x00, 0x13]), code: code) == .notFound)
    }

    @Test("Only the request line is read: it must have ended, be ASCII and fit the limit; headers may be anything")
    func requestLine() {
        let code = "k7m2qp"
        #expect(BroadcastHTTP.requestLine(in: Data("GET /k7m2qp HT".utf8)) == nil)
        #expect(BroadcastHTTP.requestLine(in: request("GET /k7m2qp HTTP/1.1")) == Data("GET /k7m2qp HTTP/1.1".utf8))
        #expect(BroadcastHTTP.route(for: Data("GET /k7m2qp HTTP/1.1".utf8), code: code) == .notFound)

        var accented = Data("GET /k7m2qp/stream HTTP/1.1\r\nUser-Agent: Voiture ".utf8)
        accented.append(contentsOf: [0xC3]) // Half a UTF-8 character, as a receive can end mid-header.
        #expect(BroadcastHTTP.route(for: accented, code: code) == .stream)
        #expect(BroadcastHTTP.route(for: request("GET /k7m2qp\u{E9} HTTP/1.1"), code: code) == .notFound)

        let long = "GET /k7m2qp?" + String(repeating: "a", count: BroadcastHTTP.requestLimit) + " HTTP/1.1"
        #expect(BroadcastHTTP.route(for: request(long), code: code) == .notFound)
    }

    @Test("A wrong address is known by its path alone, so a tab retrying an old code is one miss, not one a second")
    func pathWithoutQuery() {
        #expect(BroadcastHTTP.path(of: request("GET /oldcde/stream?1760870400 HTTP/1.1")) == "/oldcde/stream")
        #expect(BroadcastHTTP.path(of: request("GET /oldcde/stream?1760870401 HTTP/1.1")) == "/oldcde/stream")
        #expect(BroadcastHTTP.path(of: request("GET /k7m2qp HTTP/1.1")) == "/k7m2qp")
        #expect(BroadcastHTTP.path(of: request("POST /k7m2qp HTTP/1.1")) == nil)
    }

    @Test("The app and its extension work out the same code, however iOS spells the path")
    func code() {
        let app = URL(filePath: "/var/containers/Bundle/Application/7A1C/Roadivo.app")
        let privateApp = URL(filePath: "/private/var/containers/Bundle/Application/7A1C/Roadivo.app")
        let broadcast = privateApp.appending(path: "PlugIns/RoadivoBroadcast.appex")

        let code = BroadcastHTTP.code(forBundleAt: app)
        #expect(code.count == 6)
        #expect(code.allSatisfy { "abcdefghjkmnpqrstuvwxyz23456789".contains($0) })
        #expect(BroadcastHTTP.code(forBundleAt: privateApp) == code)
        #expect(BroadcastHTTP.code(forBundleAt: broadcast) == code)
    }

    @Test("Another install folder gets another code")
    func codePerInstall() {
        let app = URL(filePath: "/var/containers/Bundle/Application/7A1C/Roadivo.app")
        let reinstalled = URL(filePath: "/var/containers/Bundle/Application/93FE/Roadivo.app")
        #expect(BroadcastHTTP.code(forBundleAt: reinstalled) != BroadcastHTTP.code(forBundleAt: app))
    }

    @Test("Private, link-local and loopback peers may connect; public ones may not", arguments: [
        ("10.4.0.9", true), ("172.16.0.1", true), ("172.20.10.2", true), ("172.31.255.1", true),
        ("192.168.1.40", true), ("169.254.3.3", true), ("127.0.0.1", true),
        ("fe80::1c2b:3aff:fe4d:5e6f", true), ("febf::1", true), ("fd12:3456::1", true), ("fc00::1", true),
        ("::1", true), ("::ffff:192.168.1.40", true),
        ("8.8.8.8", false), ("172.15.0.1", false), ("172.32.0.1", false), ("192.169.0.1", false),
        ("100.64.0.1", false), ("11.0.0.1", false), ("2001:db8::1", false), ("fec0::1", false),
        ("::ffff:8.8.8.8", false), ("::", false)
    ])
    func localPeer(address: String, isLocal: Bool) {
        let bytes = IPv4Address(address)?.rawValue ?? IPv6Address(address)?.rawValue
        #expect(bytes.map(BroadcastPeer.isLocal) == isLocal)
    }

    @Test("An address that isn't 4 or 16 bytes is refused")
    func malformedPeer() {
        #expect(!BroadcastPeer.isLocal(Data()))
        #expect(!BroadcastPeer.isLocal(Data([192, 168, 1])))
    }

    @Test("The page fills the browser with this code's stream and reconnects by itself")
    func page() throws {
        let response = try #require(String(bytes: BroadcastHTTP.pageResponse(code: "k7m2qp"), encoding: .utf8))
        #expect(response.hasPrefix("HTTP/1.1 200 OK\r\n"))
        #expect(response.contains("Content-Type: text/html"))
        #expect(response.contains("'/k7m2qp/stream?'"))
        #expect(response.contains("onerror"))
        #expect(response.contains("<link rel=\"icon\" href=\"data:,\">")) // No /favicon.ico request, so no 404 counted.
        #expect(response.contains("Content-Length: \(Data(BroadcastHTTP.page(code: "k7m2qp").utf8).count)\r\n"))
    }

    @Test("The stream is MJPEG: one header, then each frame as a part with its length")
    func stream() throws {
        let header = try #require(String(bytes: BroadcastHTTP.streamHeader, encoding: .utf8))
        #expect(header.contains("multipart/x-mixed-replace; boundary=\(BroadcastHTTP.boundary)"))
        #expect(header.hasSuffix("\r\n\r\n"))

        let jpeg = Data([0xFF, 0xD8, 0x01, 0x02, 0xFF, 0xD9])
        let part = BroadcastHTTP.part(jpeg)
        let head = "--\(BroadcastHTTP.boundary)\r\nContent-Type: image/jpeg\r\nContent-Length: 6\r\n\r\n"
        #expect(part.prefix(head.utf8.count) == Data(head.utf8))
        #expect(part.dropFirst(head.utf8.count).prefix(jpeg.count) == jpeg)
        #expect(part.suffix(2) == Data("\r\n".utf8))
    }

    @Test("The car is told the Wi-Fi address first, then the Personal Hotspot's; never cellular or VPN")
    func address() {
        typealias Interface = BroadcastAddress.Interface
        let wifi = Interface(name: "en0", address: "192.168.1.23")
        let hotspot = Interface(name: "bridge100", address: "172.20.10.1")
        let cellular = Interface(name: "pdp_ip0", address: "10.44.2.9")
        let vpn = Interface(name: "utun3", address: "10.8.0.2")

        #expect(BroadcastAddress.best(of: [cellular, hotspot, wifi]) == "192.168.1.23")
        #expect(BroadcastAddress.best(of: [cellular, vpn, hotspot]) == "172.20.10.1")
        #expect(BroadcastAddress.best(of: [cellular, vpn]) == nil)
    }
}
