import Foundation
import OSLog

/// A sign-in code to type at plex.tv/link.
struct PlexPin: Equatable, Sendable {
    let id: Int
    let code: String
    let expiresAt: Date
}

/// A Plex Media Server the account can use, owned or shared.
struct PlexServer: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let isOwned: Bool
    /// The token for this server; differs from the account's on shared servers.
    let accessToken: String
    let connections: [PlexConnection]
}

struct PlexConnection: Equatable, Sendable {
    let uri: URL
    let isLocal: Bool
    let isRelay: Bool

    /// Remote HTTPS first, so a server added on home Wi-Fi keeps working on the road; then local,
    /// then relays (slow). Plain HTTP over the internet is last: it would expose the token.
    var rank: Int {
        let isSecure = uri.scheme?.lowercased() == "https"
        if isRelay {
            return isSecure ? 4 : 5
        }
        if isLocal {
            return isSecure ? 1 : 2
        }
        return isSecure ? 0 : 6
    }
}

enum PlexError: LocalizedError, Equatable {
    case codeExpired
    case noServers
    case serverUnreachable

    var errorDescription: String? {
        switch self {
        case .codeExpired: String(appLocalized: "The code expired. Get a new one.")
        case .noServers:
            String(appLocalized: """
            This Plex account has no media server. PlayCarTV plays your own Plex Media Server (on a computer or \
            NAS) or one shared with you, not Plex's free Movies & TV.
            """)
        case .serverUnreachable: String(appLocalized: "Couldn't reach this Plex server. Check that it's on and online.")
        }
    }
}

/// The plex.tv side of signing in: a code, the account's servers, and a working address for one.
protocol PlexLinking: Sendable {
    func createPin() async throws -> PlexPin
    /// The account token once the code has been entered at plex.tv/link; nil while waiting.
    func token(for pin: PlexPin) async throws -> String?
    func servers(token: String) async throws -> [PlexServer]
    /// Signs in to `server` over its best address that answers (see `PlexConnection.rank`).
    func account(for server: PlexServer) async throws -> MediaServerAccount
}

/// Plex through its HTTP API (PIN sign-in, plex.tv resources, library sections). Movies and episodes
/// in MP4 or MOV play directly; everything else through Plex's HLS transcoder.
struct PlexClient: PlexLinking {
    var session: URLSession = .shared
    let clientID: String

    static let linkPage = URL(string: "https://plex.tv/link")

    func createPin() async throws -> PlexPin {
        let request = try plexTV("api/v2/pins", query: ["strong": "false"], method: "POST")
        let pin: PinResponse = try await decode(request)
        return PlexPin(
            id: pin.id,
            code: pin.code,
            expiresAt: Date().addingTimeInterval(TimeInterval(pin.expiresIn ?? 900))
        )
    }

    func token(for pin: PlexPin) async throws -> String? {
        let request = try plexTV("api/v2/pins/\(pin.id)", query: ["code": pin.code])
        do {
            let response: PinResponse = try await decode(request)
            return response.authToken.flatMap { $0.isEmpty ? nil : $0 }
        } catch MediaServerError.httpStatus(404) {
            throw PlexError.codeExpired
        }
    }

    func servers(token: String) async throws -> [PlexServer] {
        var request = try plexTV(
            "api/v2/resources",
            host: "clients.plex.tv",
            query: ["includeHttps": "1", "includeRelay": "1", "includeIPv6": "1"]
        )
        request.setValue(token, forHTTPHeaderField: "X-Plex-Token")
        let resources: [Resource] = try await decode(request)
        // Counts and kinds only (never names or tokens), to tell "no server" from a missed one.
        let kinds = resources.map(\.provides).joined(separator: " | ")
        Logger(subsystem: "com.playcartv", category: "Plex")
            .info("Plex resources: \(resources.count, privacy: .public) [\(kinds, privacy: .public)]")
        let servers = resources.filter { $0.provides.split(separator: ",").contains("server") }.compactMap { resource in
            resource.accessToken.map { token in
                PlexServer(
                    id: resource.clientIdentifier,
                    name: resource.name,
                    isOwned: resource.owned ?? false,
                    accessToken: token,
                    connections: resource.connections.compactMap { connection in
                        URL(string: connection.uri).map {
                            PlexConnection(
                                uri: $0,
                                isLocal: connection.local ?? false,
                                isRelay: connection.relay ?? false
                            )
                        }
                    }
                )
            }
        }
        guard !servers.isEmpty else { throw PlexError.noServers }
        return servers
    }

    func account(for server: PlexServer) async throws -> MediaServerAccount {
        for connection in server.connections.sorted(by: { $0.rank < $1.rank }) {
            var request = URLRequest(url: connection.uri.appending(path: "identity"), timeoutInterval: 5)
            addHeaders(to: &request, token: server.accessToken)
            if let (_, response) = try? await session.data(for: request), // Unreachable: try the next address.
               let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
                return MediaServerAccount(
                    kind: .plex,
                    baseURL: connection.uri,
                    userID: server.id,
                    token: server.accessToken
                )
            }
        }
        throw PlexError.serverUnreachable
    }

    /// Every movie and episode in the server's movie and TV libraries, in library order.
    func library(for account: MediaServerAccount) async throws -> [PlaylistEntry] {
        let sections: PlexContainer<Section> = try await decode(serverRequest(account, path: "library/sections"))
        var entries: [PlaylistEntry] = []
        for section in sections.mediaContainer.items where section.type == "movie" || section.type == "show" {
            let type = section.type == "movie" ? "1" : "4"
            var start = 0
            while entries.count < 20000 {
                let page: PlexContainer<Item> = try await decode(serverRequest(
                    account,
                    path: "library/sections/\(section.key)/all",
                    query: ["type": type, "X-Plex-Container-Start": "\(start)", "X-Plex-Container-Size": "500"]
                ))
                entries += page.mediaContainer.items.compactMap { entry(for: $0, section: section, account: account) }
                start += page.mediaContainer.items.count
                if page.mediaContainer.items.isEmpty || start >= (page.mediaContainer.totalSize ?? start) {
                    break
                }
            }
        }
        return entries
    }

    // MARK: Requests

    private func plexTV(
        _ path: String,
        host: String = "plex.tv",
        query: [String: String],
        method: String = "GET"
    ) throws -> URLRequest {
        guard var components = URLComponents(string: "https://\(host)/\(path)")
        else { throw MediaServerError.invalidAddress }
        components.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components.url else { throw MediaServerError.invalidAddress }
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.httpMethod = method
        addHeaders(to: &request, token: nil)
        return request
    }

    private func serverRequest(
        _ account: MediaServerAccount,
        path: String,
        query: [String: String] = [:]
    ) throws -> URLRequest {
        guard var components = URLComponents(url: account.baseURL.appending(path: path), resolvingAgainstBaseURL: false)
        else { throw MediaServerError.invalidAddress }
        if !query.isEmpty {
            components.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components.url else { throw MediaServerError.invalidAddress }
        var request = URLRequest(url: url, timeoutInterval: 30)
        addHeaders(to: &request, token: account.token)
        return request
    }

    private func addHeaders(to request: inout URLRequest, token: String?) {
        let headers = [
            "Accept": "application/json",
            "X-Plex-Product": "PlayCarTV",
            "X-Plex-Version": "1.0",
            "X-Plex-Client-Identifier": clientID,
            "X-Plex-Platform": "iOS",
            "X-Plex-Device": "iPhone",
            "X-Plex-Device-Name": "PlayCarTV"
        ]
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        if let token {
            request.setValue(token, forHTTPHeaderField: "X-Plex-Token")
        }
    }

    private func decode<T: Decodable>(_ request: URLRequest) async throws -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw MediaServerError.unreachable(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else { throw MediaServerError.unexpectedResponse }
        if http.statusCode == 401 {
            throw MediaServerError.badCredentials
        }
        guard (200..<300).contains(http.statusCode) else { throw MediaServerError.httpStatus(http.statusCode) }
        guard let value = try? JSONDecoder().decode(T.self, from: data)
        else { throw MediaServerError.unexpectedResponse }
        return value
    }

    // MARK: Entries

    private func entry(for item: Item, section: Section, account: MediaServerAccount) -> PlaylistEntry? {
        guard let stream = streamURL(for: item, account: account) else { return nil }
        let isEpisode = item.type == "episode"
        var name = item.title
        if isEpisode, let season = item.parentIndex, let episode = item.index {
            name = "S\(season) · E\(episode) — \(item.title)"
        }
        let group = isEpisode ? (item.grandparentTitle ?? section.title) : section.title
        // A film's thumb is its poster; an episode's is a 16:9 still.
        let isFilm = item.type == "movie"
        let poster = (item.thumb ?? item.grandparentThumb).flatMap { thumb in
            url(
                account,
                path: "photo/:/transcode",
                query: ["url": thumb, "width": isFilm ? "360" : "480", "height": isFilm ? "540" : "270", "minSize": "1"]
            )
        }
        return PlaylistEntry(
            name: name,
            group: group,
            logoURL: poster,
            streamURL: stream,
            year: isFilm ? item.year : nil,
            artwork: isFilm ? .poster : .still
        )
    }

    /// AVPlayer plays MP4 and MOV as they are; the server transcodes the rest to HLS.
    private func streamURL(for item: Item, account: MediaServerAccount) -> URL? {
        let media = item.media?.first
        if let part = media?.parts?.first, let key = part.key,
           ["mp4", "m4v", "mov"].contains((part.container ?? media?.container ?? "").lowercased()) {
            return url(account, path: String(key.drop { $0 == "/" }), query: [:])
        }
        return url(account, path: "video/:/transcode/universal/start.m3u8", query: [
            "path": "/library/metadata/\(item.ratingKey)",
            "mediaIndex": "0",
            "partIndex": "0",
            "protocol": "hls",
            "directPlay": "0",
            "directStream": "1",
            "fastSeek": "1",
            "maxVideoBitrate": "8000",
            "videoResolution": "1920x1080",
            "session": "playcartv-\(item.ratingKey)",
            "X-Plex-Client-Identifier": clientID,
            "X-Plex-Product": "PlayCarTV",
            "X-Plex-Platform": "iOS"
        ])
    }

    /// AVPlayer and image loading can't send headers, so the server's token rides in the query,
    /// as with Jellyfin's api_key. It's kept in the app's private store, never logged.
    private func url(_ account: MediaServerAccount, path: String, query: [String: String]) -> URL? {
        guard var components = URLComponents(url: account.baseURL.appending(path: path), resolvingAgainstBaseURL: false)
        else { return nil }
        components.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
            + [URLQueryItem(name: "X-Plex-Token", value: account.token)]
        return components.url
    }

    // MARK: Responses

    private struct PinResponse: Decodable {
        let id: Int
        let code: String
        let expiresIn: Int?
        let authToken: String?
        enum CodingKeys: String, CodingKey {
            case id, code, expiresIn, authToken
        }
    }

    private struct Resource: Decodable {
        let name: String
        let provides: String
        let owned: Bool?
        let accessToken: String?
        let clientIdentifier: String
        let connections: [Connection]
        enum CodingKeys: String, CodingKey {
            case name, provides, owned, accessToken, clientIdentifier, connections
        }
    }

    private struct Connection: Decodable {
        let uri: String
        let local: Bool?
        let relay: Bool?
        enum CodingKeys: String, CodingKey {
            case uri, local, relay
        }
    }

    private struct Section: Decodable {
        let key: String
        let title: String
        let type: String
        enum CodingKeys: String, CodingKey {
            case key, title, type
        }
    }

    private struct Item: Decodable {
        let ratingKey: String
        let title: String
        let type: String
        let thumb: String?
        let grandparentThumb: String?
        let grandparentTitle: String?
        let parentIndex: Int?
        let index: Int?
        let year: Int?
        let media: [Media]?
        enum CodingKeys: String, CodingKey {
            case ratingKey, title, type, thumb, grandparentThumb, grandparentTitle, parentIndex, index, year
            case media = "Media"
        }
    }

    private struct Media: Decodable {
        let container: String?
        let parts: [Part]?
        enum CodingKeys: String, CodingKey {
            case container
            case parts = "Part"
        }
    }

    private struct Part: Decodable {
        let key: String?
        let container: String?
        enum CodingKeys: String, CodingKey {
            case key, container
        }
    }
}

/// Plex wraps every list in `MediaContainer`, as `Directory` (sections) or `Metadata` (items).
private struct PlexContainer<Element: Decodable>: Decodable {
    let mediaContainer: Body
    enum CodingKeys: String, CodingKey { case mediaContainer = "MediaContainer" }

    struct Body: Decodable {
        let items: [Element]
        let totalSize: Int?

        enum CodingKeys: String, CodingKey {
            case directory = "Directory"
            case metadata = "Metadata"
            case totalSize
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            items = try container.decodeIfPresent([Element].self, forKey: .directory)
                ?? container.decodeIfPresent([Element].self, forKey: .metadata) ?? []
            totalSize = try container.decodeIfPresent(Int.self, forKey: .totalSize)
        }
    }
}
