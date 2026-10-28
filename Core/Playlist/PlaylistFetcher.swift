import Foundation

/// Downloads a playlist's text. A protocol so tests never touch the network.
protocol PlaylistFetching: Sendable {
    func fetchText(from url: URL) async throws -> String
}

struct URLSessionPlaylistFetcher: PlaylistFetching {
    var session: URLSession = .shared
    /// The biggest provider exports run to tens of MB; anything larger is usually a video link,
    /// which would download until iOS stops the app.
    var maximumBytes = 100 * 1024 * 1024
    /// How far into the body a NUL byte marks it as video or audio. Text
    /// playlists never contain one; TS and MP4 data has one within bytes.
    private static let sniffLength = 4096

    func fetchText(from url: URL) async throws -> String {
        var request = URLRequest(url: url, timeoutInterval: 30)
        // Some IPTV servers reject requests without a player-style user agent.
        request.setValue("PlayCarTV/1.0 (iPhone)", forHTTPHeaderField: "User-Agent")
        let bytes: URLSession.AsyncBytes
        let response: URLResponse
        do {
            (bytes, response) = try await session.bytes(for: request)
        } catch {
            throw LibraryError.download(error.localizedDescription)
        }
        // Stops the transfer when reading ends early; a no-op once it finished.
        defer { bytes.task.cancel() }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw LibraryError.httpStatus(http.statusCode)
        }
        guard response.expectedContentLength <= Int64(maximumBytes) else { throw LibraryError.tooLarge }
        return try await PlaylistText.decode(body(of: bytes))
    }

    private func body(of bytes: URLSession.AsyncBytes) async throws -> Data {
        var body: [UInt8] = []
        do {
            for try await byte in bytes {
                if byte == 0, body.count < Self.sniffLength {
                    throw LibraryError.mediaFile
                }
                guard body.count < maximumBytes else { throw LibraryError.tooLarge }
                body.append(byte)
            }
        } catch let error as LibraryError {
            throw error
        } catch {
            throw LibraryError.download(error.localizedDescription)
        }
        return Data(body)
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
