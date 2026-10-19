import CryptoKit
import Foundation

/// The small web server Screen Broadcast runs on the iPhone (DECISIONS 124): `/<code>` is a page that fills the car
/// screen's browser with `/<code>/stream`, the iPhone's screen as JPEG frames (MJPEG), which every browser shows.
/// Compiled into the app (its address, its tests) and the broadcast extension (the server).
enum BroadcastHTTP {
    static let port: UInt16 = 8080
    static let boundary = "roadivo-frame"

    /// This install's private code, so others on the same Wi-Fi can't guess the address. The app and its extension
    /// share no storage, but both live in the app's install folder, whose random name is theirs alone.
    static var code: String {
        code(forBundleAt: Bundle.main.bundleURL)
    }

    /// Six easy-to-type characters (no 0/o, 1/l/i) from the install folder; an update or reinstall changes it.
    static func code(forBundleAt bundleURL: URL) -> String {
        var components = bundleURL.standardizedFileURL.pathComponents
        // Only "<install folder>/Roadivo.app": the extension sits inside the app, and `/var` may read `/private/var`.
        if let app = components.firstIndex(where: { $0.hasSuffix(".app") }) {
            components = Array(components[max(app - 1, 0)...app])
        }
        let alphabet = Array("abcdefghjkmnpqrstuvwxyz23456789")
        let digest = SHA256.hash(data: Data(components.joined(separator: "/").utf8))
        return String(digest.prefix(6).map { alphabet[Int($0) % alphabet.count] })
    }

    enum Route: Equatable {
        case page
        case stream
        case notFound
    }

    /// The most a browser may send before its request line ends; real ones send a few hundred bytes.
    static let requestLimit = 8 * 1024

    /// The request line's bytes once its "\r\n" has arrived, else nil; the headers after it are never read.
    static func requestLine(in request: Data) -> Data? {
        request.range(of: Data("\r\n".utf8)).map { request[request.startIndex..<$0.lowerBound] }
    }

    /// The path a GET asks for, without its query: "/k7m2qp/stream" from "GET /k7m2qp/stream?123 HTTP/1.1".
    /// Nil for any other method, or a request line that is unfinished, too long or not ASCII.
    static func path(of request: Data) -> String? {
        guard let line = requestLine(in: request), line.count <= requestLimit, line.allSatisfy(UTF8.isASCII),
              let text = String(bytes: line, encoding: .ascii) else { return nil }
        let parts = text.split(separator: " ")
        guard parts.count >= 2, parts[0] == "GET" else { return nil }
        return String(parts[1].prefix { $0 != "?" })
    }

    /// Only a GET for this code's page or stream is served.
    static func route(for request: Data, code: String) -> Route {
        guard let target = path(of: request) else { return .notFound }
        switch target {
        case "/\(code)", "/\(code)/":
            return .page
        case "/\(code)/stream":
            return .stream
        default:
            return .notFound
        }
    }

    static func pageResponse(code: String) -> Data {
        response(status: "200 OK", type: "text/html; charset=utf-8", body: Data(page(code: code).utf8))
    }

    static var notFoundResponse: Data {
        response(status: "404 Not Found", type: "text/plain", body: Data("Not found".utf8))
    }

    /// Starts the stream; each frame then follows as one `part`.
    static var streamHeader: Data {
        Data((
            "HTTP/1.1 200 OK\r\nContent-Type: multipart/x-mixed-replace; boundary=\(boundary)\r\n"
                + "Cache-Control: no-cache, no-store\r\nPragma: no-cache\r\nConnection: close\r\n\r\n"
        ).utf8)
    }

    static func part(_ jpeg: Data) -> Data {
        var data = Data("--\(boundary)\r\nContent-Type: image/jpeg\r\nContent-Length: \(jpeg.count)\r\n\r\n".utf8)
        data.append(jpeg)
        data.append(Data("\r\n".utf8))
        return data
    }

    private static func response(status: String, type: String, body: Data) -> Data {
        var data = Data((
            "HTTP/1.1 \(status)\r\nContent-Type: \(type)\r\nContent-Length: \(body.count)\r\n"
                + "Cache-Control: no-cache\r\nConnection: close\r\n\r\n"
        ).utf8)
        data.append(body)
        return data
    }

    /// Black and full screen, the iPhone's picture fitted inside; it reconnects by itself if the stream drops.
    /// The empty icon stops the browser asking for /favicon.ico, which would count as a wrong address.
    static func page(code: String) -> String {
        """
        <!doctype html>
        <html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
        <title>Roadivo</title><link rel="icon" href="data:,">
        <style>html,body{margin:0;height:100%;background:#000;overflow:hidden}
        img{width:100%;height:100%;object-fit:contain;display:block}</style></head>
        <body><img id="s" alt="">
        <script>var s=document.getElementById('s');
        function go(){s.src='/\(code)/stream?'+Date.now();}
        s.onerror=function(){setTimeout(go,1000);};
        go();</script></body></html>
        """
    }
}

/// Who may connect: only a device on the same Wi-Fi or hotspot (a private, link-local or loopback address).
enum BroadcastPeer {
    /// `address` is an IPv4 (4 bytes) or IPv6 (16 bytes) address as Network gives it; anything else is refused.
    static func isLocal(_ address: Data) -> Bool {
        let bytes = [UInt8](address)
        switch bytes.count {
        case 4:
            return isLocalIPv4(bytes)
        case 16:
            // An IPv4 address carried as IPv6 (::ffff:a.b.c.d) is judged as IPv4.
            if bytes.prefix(10).allSatisfy({ $0 == 0 }), bytes[10] == 0xFF, bytes[11] == 0xFF {
                return isLocalIPv4(Array(bytes.suffix(4)))
            }
            let isLoopback = bytes.dropLast().allSatisfy { $0 == 0 } && bytes[15] == 1
            let isLinkLocal = bytes[0] == 0xFE && (bytes[1] & 0xC0) == 0x80 // fe80::/10
            let isUniqueLocal = (bytes[0] & 0xFE) == 0xFC // fc00::/7
            return isLoopback || isLinkLocal || isUniqueLocal
        default:
            return false
        }
    }

    /// 10/8, 172.16/12, 192.168/16, link-local 169.254/16 and loopback 127/8.
    private static func isLocalIPv4(_ bytes: [UInt8]) -> Bool {
        switch (bytes[0], bytes[1]) {
        case (10, _), (127, _), (169, 254), (172, 16...31), (192, 168):
            true
        default:
            false
        }
    }
}

/// The address the car screen's browser opens: this iPhone's Wi-Fi address, or its Personal Hotspot's.
enum BroadcastAddress {
    struct Interface: Equatable {
        let name: String
        let address: String
    }

    static func current() -> String? {
        best(of: interfaces()).map { "http://\($0):\(BroadcastHTTP.port)/\(BroadcastHTTP.code)" }
    }

    /// Wi-Fi (en0) first, then the Personal Hotspot (bridge…): cellular and VPN addresses can't be reached from the
    /// car.
    static func best(of interfaces: [Interface]) -> String? {
        interfaces.first { $0.name == "en0" }?.address ?? interfaces.first { $0.name.hasPrefix("bridge") }?.address
    }

    /// Every IPv4 address this iPhone has, by interface.
    private static func interfaces() -> [Interface] {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return [] }
        defer { freeifaddrs(head) }
        var found: [Interface] = []
        for entry in sequence(first: first, next: { $0.pointee.ifa_next }).map(\.pointee) {
            guard let socket = entry.ifa_addr, socket.pointee.sa_family == UInt8(AF_INET) else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let length = socklen_t(socket.pointee.sa_len)
            guard getnameinfo(socket, length, &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0
            else { continue }
            let bytes = host.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
            guard let address = String(bytes: bytes, encoding: .utf8) else { continue }
            found.append(Interface(name: String(cString: entry.ifa_name), address: address))
        }
        return found
    }
}
