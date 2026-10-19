import Foundation

/// The small web server Screen Broadcast runs on the iPhone (DECISIONS 124): `/` is a page that fills the car
/// screen's browser with `/stream`, the iPhone's screen as a stream of JPEG frames (MJPEG), which every browser
/// shows. Compiled into the app (its address, its tests) and the broadcast extension (the server).
enum BroadcastHTTP {
    static let port: UInt16 = 8080
    static let boundary = "roadivo-frame"

    enum Route: Equatable {
        case page
        case stream
        case notFound
    }

    /// From the request line ("GET /stream?123 HTTP/1.1"): only a GET for the page or the stream is served.
    static func route(for request: Data) -> Route {
        guard let text = String(data: request.prefix(2048), encoding: .utf8),
              let line = text.split(separator: "\r\n", maxSplits: 1).first else { return .notFound }
        let parts = line.split(separator: " ")
        guard parts.count >= 2, parts[0] == "GET" else { return .notFound }
        switch parts[1].split(separator: "?").first ?? "" {
        case "/", "/index.html":
            return .page
        case "/stream":
            return .stream
        default:
            return .notFound
        }
    }

    static var pageResponse: Data {
        response(status: "200 OK", type: "text/html; charset=utf-8", body: Data(page.utf8))
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
    static let page = """
    <!doctype html>
    <html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
    <title>Roadivo</title>
    <style>html,body{margin:0;height:100%;background:#000;overflow:hidden}
    img{width:100%;height:100%;object-fit:contain;display:block}</style></head>
    <body><img id="s" alt="">
    <script>var s=document.getElementById('s');
    function go(){s.src='/stream?'+Date.now();}
    s.onerror=function(){setTimeout(go,1000);};
    go();</script></body></html>
    """
}

/// The address the car screen's browser opens: this iPhone's Wi-Fi address, or its Personal Hotspot's.
enum BroadcastAddress {
    struct Interface: Equatable {
        let name: String
        let address: String
    }

    static func current() -> String? {
        best(of: interfaces()).map { "http://\($0):\(BroadcastHTTP.port)" }
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
