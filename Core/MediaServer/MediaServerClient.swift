import Foundation

/// A signed-in Jellyfin or Emby account. Kept as JSON in the Keychain: the
/// access token is a credential.
struct MediaServerAccount: Codable, Equatable, Sendable {
    let kind: MediaServerKind
    let baseURL: URL
    let userID: String
    let token: String
    /// The server's own name ("Stable Demo"), for naming the source. Absent in older logins.
    var serverName: String?
}

enum MediaServerError: LocalizedError, Equatable {
    case invalidAddress
    case badCredentials
    case unreachable(String)
    case httpStatus(Int)
    case unexpectedResponse
    case emptyLibrary

    var errorDescription: String? {
        switch self {
        case .invalidAddress:
            String(appLocalized: "Check the server address, for example http://192.168.1.10:8096.")
        case .badCredentials:
            String(appLocalized: "The username or password is incorrect.")
        case let .unreachable(reason):
            String(appLocalized: "Couldn't reach the server. \(reason)")
        case let .httpStatus(code):
            String(appLocalized: "The server answered with error \(code).")
        case .unexpectedResponse:
            String(appLocalized: "That doesn't look like a Jellyfin or Emby server.")
        case .emptyLibrary:
            String(appLocalized: "We couldn't find any movies or episodes on that server.")
        }
    }
}

/// Signs in to a media server and lists its playable items.
protocol MediaServerConnecting: Sendable {
    func signIn(kind: MediaServerKind, baseURL: URL, username: String, password: String) async throws
        -> MediaServerAccount
    func library(for account: MediaServerAccount) async throws -> [PlaylistEntry]
}

/// Jellyfin forked from Emby and kept its API, so one client serves both. Video is requested
/// as HLS so the server transcodes what AVPlayer can't play (MKV, AC3…).
struct EmbyCompatibleClient: MediaServerConnecting {
    var session: URLSession = .shared
    let deviceID: String

    static let maximumItems = 20000
    static let pageSize = 1000

    func signIn(kind: MediaServerKind, baseURL: URL, username: String, password: String) async throws
        -> MediaServerAccount {
        var request = URLRequest(url: baseURL.appending(path: "Users/AuthenticateByName"), timeoutInterval: 20)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Jellyfin reads `Authorization`, Emby `X-Emby-Authorization`.
        request.setValue(authorization(), forHTTPHeaderField: "Authorization")
        request.setValue(authorization(), forHTTPHeaderField: "X-Emby-Authorization")
        request.httpBody = try JSONEncoder().encode(["Username": username, "Pw": password])
        let data = try await send(request, unauthorizedIs: .badCredentials)
        guard let response = try? JSONDecoder().decode(AuthResponse.self, from: data) else {
            throw MediaServerError.unexpectedResponse
        }
        return await MediaServerAccount(
            kind: kind,
            baseURL: baseURL,
            userID: response.user.id,
            token: response.accessToken,
            serverName: serverName(at: baseURL)
        )
    }

    /// The name the owner gave the server, from its public info. Only a label, so a failure is nil.
    private func serverName(at baseURL: URL) async -> String? {
        let request = URLRequest(url: baseURL.appending(path: "System/Info/Public"), timeoutInterval: 10)
        guard let data = try? await send(request, unauthorizedIs: .badCredentials),
              let info = try? JSONDecoder().decode(PublicInfo.self, from: data) else { return nil }
        let name = info.serverName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? nil : name
    }

    /// Every movie and episode, a page at a time up to `maximumItems`, like Plex.
    func library(for account: MediaServerAccount) async throws -> [PlaylistEntry] {
        var entries: [PlaylistEntry] = []
        var start = 0
        while start < Self.maximumItems {
            let page = try await itemsPage(account, start: start)
            entries += page.items.compactMap { entry(for: $0, account: account) }
            start += page.items.count
            // A short page is the last; servers that omit the total stop there too.
            if page.items.count < Self.pageSize || start >= (page.totalRecordCount ?? .max) {
                break
            }
        }
        return entries
    }

    // MARK: Helpers

    private func itemsPage(_ account: MediaServerAccount, start: Int) async throws -> ItemsResponse {
        guard var components = URLComponents(
            url: account.baseURL.appending(path: "Users/\(account.userID)/Items"),
            resolvingAgainstBaseURL: false
        ) else { throw MediaServerError.invalidAddress }
        components.queryItems = [
            URLQueryItem(name: "Recursive", value: "true"),
            URLQueryItem(name: "IncludeItemTypes", value: "Movie,Episode"),
            URLQueryItem(name: "Fields", value: "SeriesName"),
            URLQueryItem(name: "SortBy", value: "SeriesSortName,ParentIndexNumber,IndexNumber,SortName"),
            URLQueryItem(name: "StartIndex", value: "\(start)"),
            URLQueryItem(name: "Limit", value: "\(Self.pageSize)")
        ] + tokenQuery(account)
        guard let url = components.url else { throw MediaServerError.invalidAddress }
        var request = URLRequest(url: url, timeoutInterval: 30)
        let header = authorization(token: account.token)
        request.setValue(header, forHTTPHeaderField: "Authorization")
        request.setValue(header, forHTTPHeaderField: "X-Emby-Authorization")
        let data = try await send(request, unauthorizedIs: .badCredentials)
        guard let response = try? JSONDecoder().decode(ItemsResponse.self, from: data) else {
            throw MediaServerError.unexpectedResponse
        }
        return response
    }

    /// Jellyfin 10.12 only accepts a token here or as `ApiKey`; Emby reads `X-Emby-Authorization`.
    private func authorization(token: String? = nil) -> String {
        let base = #"MediaBrowser Client="PlayCarTV", Device="iPhone", DeviceId="\#(deviceID)", Version="1.0.0""#
        return token.map { base + #", Token="\#($0)""# } ?? base
    }

    /// AVPlayer and image loading can't send headers, so the token rides in the query. Jellyfin 10.12
    /// turned off the legacy `api_key`, so it also gets `ApiKey`; Emby only knows `api_key`.
    private func tokenQuery(_ account: MediaServerAccount) -> [URLQueryItem] {
        var items = [URLQueryItem(name: "api_key", value: account.token)]
        if account.kind == .jellyfin {
            items.append(URLQueryItem(name: "ApiKey", value: account.token))
        }
        return items
    }

    private func send(_ request: URLRequest, unauthorizedIs error: MediaServerError) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw MediaServerError.unreachable(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else { throw MediaServerError.unexpectedResponse }
        if http.statusCode == 401 {
            throw error
        }
        guard (200..<300).contains(http.statusCode) else { throw MediaServerError.httpStatus(http.statusCode) }
        return data
    }

    private func entry(for item: Item, account: MediaServerAccount) -> PlaylistEntry? {
        guard let stream = url(account, path: "Videos/\(item.id)/master.m3u8", query: [
            "MediaSourceId": item.id,
            "DeviceId": deviceID,
            "VideoCodec": "h264",
            "AudioCodec": "aac",
            "TranscodingMaxAudioChannels": "2"
        ]) else { return nil }
        let isEpisode = item.type == "Episode"
        // A film's Primary image is its poster; an episode's is a 16:9 still.
        let poster = url(
            account,
            path: "Items/\(item.id)/Images/Primary",
            query: ["maxWidth": isEpisode ? "480" : "360"]
        )
        var name = item.name
        if isEpisode, let season = item.season, let episode = item.episode {
            name = "S\(season) · E\(episode) — \(item.name)"
        }
        let group = isEpisode ? (item.seriesName ?? String(appLocalized: "TV")) : String(appLocalized: "Movies")
        return PlaylistEntry(
            name: name,
            group: group,
            logoURL: poster,
            streamURL: stream,
            year: isEpisode ? nil : item.year,
            artwork: isEpisode ? .still : .poster
        )
    }

    private func url(_ account: MediaServerAccount, path: String, query: [String: String]) -> URL? {
        guard var components = URLComponents(url: account.baseURL.appending(path: path), resolvingAgainstBaseURL: false)
        else { return nil }
        components.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
            + tokenQuery(account)
        return components.url
    }

    private struct AuthUser: Decodable {
        let id: String
        enum CodingKeys: String, CodingKey { case id = "Id" }
    }

    private struct PublicInfo: Decodable {
        let serverName: String?
        enum CodingKeys: String, CodingKey { case serverName = "ServerName" }
    }

    private struct AuthResponse: Decodable {
        let user: AuthUser
        let accessToken: String
        enum CodingKeys: String, CodingKey {
            case user = "User"
            case accessToken = "AccessToken"
        }
    }

    private struct ItemsResponse: Decodable {
        let items: [Item]
        let totalRecordCount: Int?
        enum CodingKeys: String, CodingKey {
            case items = "Items"
            case totalRecordCount = "TotalRecordCount"
        }
    }

    private struct Item: Decodable {
        let id: String
        let name: String
        let type: String
        let seriesName: String?
        let season: Int?
        let episode: Int?
        let year: Int?
        enum CodingKeys: String, CodingKey {
            case id = "Id"
            case name = "Name"
            case type = "Type"
            case seriesName = "SeriesName"
            case season = "ParentIndexNumber"
            case episode = "IndexNumber"
            case year = "ProductionYear"
        }
    }
}
