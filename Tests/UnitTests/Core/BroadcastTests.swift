import Foundation
import Testing
@testable import Roadivo

@Suite("Screen Broadcast server")
struct BroadcastHTTPTests {
    private func request(_ line: String) -> Data {
        Data("\(line)\r\nHost: 172.20.10.1:8080\r\nAccept: */*\r\n\r\n".utf8)
    }

    @Test("The page and the stream are served; anything else is not found")
    func routes() {
        #expect(BroadcastHTTP.route(for: request("GET / HTTP/1.1")) == .page)
        #expect(BroadcastHTTP.route(for: request("GET /index.html HTTP/1.1")) == .page)
        #expect(BroadcastHTTP.route(for: request("GET /stream?1760870400 HTTP/1.1")) == .stream)
        #expect(BroadcastHTTP.route(for: request("GET /favicon.ico HTTP/1.1")) == .notFound)
        #expect(BroadcastHTTP.route(for: request("POST /stream HTTP/1.1")) == .notFound)
        #expect(BroadcastHTTP.route(for: Data([0xFF, 0x00, 0x13])) == .notFound)
    }

    @Test("The page fills the browser with the stream and reconnects by itself")
    func page() throws {
        let response = try #require(String(bytes: BroadcastHTTP.pageResponse, encoding: .utf8))
        #expect(response.hasPrefix("HTTP/1.1 200 OK\r\n"))
        #expect(response.contains("Content-Type: text/html"))
        #expect(response.contains("'/stream?'"))
        #expect(response.contains("onerror"))
        #expect(response.contains("Content-Length: \(Data(BroadcastHTTP.page.utf8).count)\r\n"))
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
