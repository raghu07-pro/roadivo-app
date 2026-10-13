import Foundation

/// Downloads a playlist's text. A protocol so tests never touch the network.
protocol PlaylistFetching: Sendable {
    func fetchText(from url: URL) async throws -> String
}

struct URLSessionPlaylistFetcher: PlaylistFetching {
    var session: URLSession = .shared

    func fetchText(from url: URL) async throws -> String {
        var request = URLRequest(url: url, timeoutInterval: 30)
        // Some IPTV servers reject requests without a player-style user agent.
        request.setValue("Roadivo/1.0 (iPhone)", forHTTPHeaderField: "User-Agent")
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw LibraryError.download(error.localizedDescription)
        }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw LibraryError.httpStatus(http.statusCode)
        }
        return try PlaylistText.decode(data)
    }
}

enum PlaylistText {
    /// UTF-8 first; Latin-1 is the common fallback for older provider exports.
    static func decode(_ data: Data) throws -> String {
        if let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) {
            return text
        }
        throw LibraryError.unreadable
    }
}
