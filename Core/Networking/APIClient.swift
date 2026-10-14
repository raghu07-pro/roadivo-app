import Foundation

/// The seam for a future backend (none in v1, DECISIONS 6); the base URL comes from
/// `API_BASE_URL` in the build's xcconfig.
struct APIClient: Sendable {
    let baseURL: URL
    let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func send<Response: Decodable & Sendable>(_ endpoint: Endpoint, as type: Response.Type) async throws -> Response {
        let request = try endpoint.urlRequest(baseURL: baseURL)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw NetworkError.transport(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else { throw NetworkError.transport("No HTTP response") }
        guard (200..<300).contains(http.statusCode) else { throw NetworkError.http(status: http.statusCode) }
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(type, from: data)
        } catch {
            throw NetworkError.decoding(String(describing: error))
        }
    }
}

enum AppInfo {
    /// `API_BASE_URL` from Info.plist (set per configuration in Config/*.xcconfig).
    static func apiBaseURL(bundle: Bundle = .main) throws -> URL {
        guard let value = bundle.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
              let url = URL(string: value), url.host() != nil else { throw NetworkError.missingBaseURL }
        return url
    }

    static var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(short) (\(build))"
    }
}
