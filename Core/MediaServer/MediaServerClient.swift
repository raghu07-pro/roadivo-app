import Foundation

/// A signed-in Jellyfin or Emby account. Kept as JSON in the Keychain: the
/// access token is a credential.
struct MediaServerAccount: Codable, Equatable, Sendable {
    let kind: MediaServerKind
    let baseURL: URL
    let userID: String
    let token: String
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

/// Jellyfin forked from Emby and kept its REST API, so one client serves both.
/// Video is requested as HLS (`master.m3u8`) so the server transcodes anything
/// AVPlayer can't play directly (MKV, AC3…).
struct EmbyCompatibleClient: MediaServerConnecting {
    var session: URLSession = .shared
    let deviceID: String

    func signIn(kind: MediaServerKind, baseURL: URL, username: String, password: String) async throws
        -> MediaServerAccount {
        var request = URLRequest(url: baseURL.appending(path: "Users/AuthenticateByName"), timeoutInterval: 20)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Jellyfin reads `Authorization`, Emby `X-Emby-Authorization`.
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
        request.setValue(authorization, forHTTPHeaderField: "X-Emby-Authorization")
        request.httpBody = try JSONEncoder().encode(["Username": username, "Pw": password])
        let data = try await send(request, unauthorizedIs: .badCredentials)
        guard let response = try? JSONDecoder().decode(AuthResponse.self, from: data) else {
            throw MediaServerError.unexpectedResponse
        }
        return MediaServerAccount(kind: kind, baseURL: baseURL, userID: response.user.id, token: response.accessToken)
    }

    func library(for account: MediaServerAccount) async throws -> [PlaylistEntry] {
        guard var components = URLComponents(
            url: account.baseURL.appending(path: "Users/\(account.userID)/Items"),
            resolvingAgainstBaseURL: false
        ) else { throw MediaServerError.invalidAddress }
        components.queryItems = [
            URLQueryItem(name: "Recursive", value: "true"),
            URLQueryItem(name: "IncludeItemTypes", value: "Movie,Episode"),
            URLQueryItem(name: "Fields", value: "SeriesName"),
            URLQueryItem(name: "SortBy", value: "SeriesSortName,ParentIndexNumber,IndexNumber,SortName"),
            URLQueryItem(name: "Limit", value: "5000"),
            URLQueryItem(name: "api_key", value: account.token)
        ]
        guard let url = components.url else { throw MediaServerError.invalidAddress }
        let data = try await send(URLRequest(url: url, timeoutInterval: 30), unauthorizedIs: .badCredentials)
        guard let response = try? JSONDecoder().decode(ItemsResponse.self, from: data) else {
            throw MediaServerError.unexpectedResponse
        }
        return response.items.compactMap { entry(for: $0, account: account) }
    }

    // MARK: Helpers

    private var authorization: String {
        #"MediaBrowser Client="Roadivo", Device="iPhone", DeviceId="\#(deviceID)", Version="1.0.0""#
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
        let poster = url(account, path: "Items/\(item.id)/Images/Primary", query: ["maxWidth": "480"])
        let isEpisode = item.type == "Episode"
        var name = item.name
        if isEpisode, let season = item.season, let episode = item.episode {
            name = "S\(season) · E\(episode) — \(item.name)"
        }
        let group = isEpisode ? (item.seriesName ?? String(appLocalized: "TV")) : String(appLocalized: "Movies")
        return PlaylistEntry(name: name, group: group, logoURL: poster, streamURL: stream)
    }

    private func url(_ account: MediaServerAccount, path: String, query: [String: String]) -> URL? {
        guard var components = URLComponents(url: account.baseURL.appending(path: path), resolvingAgainstBaseURL: false)
        else { return nil }
        components.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
            + [URLQueryItem(name: "api_key", value: account.token)]
        return components.url
    }

    private struct AuthUser: Decodable {
        let id: String
        enum CodingKeys: String, CodingKey { case id = "Id" }
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
        enum CodingKeys: String, CodingKey { case items = "Items" }
    }

    private struct Item: Decodable {
        let id: String
        let name: String
        let type: String
        let seriesName: String?
        let season: Int?
        let episode: Int?
        enum CodingKeys: String, CodingKey {
            case id = "Id"
            case name = "Name"
            case type = "Type"
            case seriesName = "SeriesName"
            case season = "ParentIndexNumber"
            case episode = "IndexNumber"
        }
    }
}
