import Foundation

/// Asks Apple's public App Store lookup for PlayCarTV's current version in this storefront. It sends
/// only the app's bundle ID and the country, nothing about the user.
struct AppStoreUpdateChecker: AppUpdateChecking {
    let bundleID: String
    let country: String
    var load: @Sendable (URLRequest) async throws -> (Data, URLResponse) = { request in
        try await URLSession.shared.data(for: request)
    }

    func latestRelease() async throws -> AppRelease? {
        var components = URLComponents(string: "https://itunes.apple.com/lookup")
        components?.queryItems = [
            URLQueryItem(name: "bundleId", value: bundleID),
            URLQueryItem(name: "country", value: country)
        ]
        guard let url = components?.url else { return nil }
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        let (data, response) = try await load(request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        // No result until the app is live in this storefront.
        guard let app = try JSONDecoder().decode(Lookup.self, from: data).results.first,
              let storeURL = URL(string: app.trackViewUrl) else { return nil }
        return AppRelease(version: app.version, notes: app.releaseNotes ?? "", storeURL: storeURL)
    }

    private struct Lookup: Decodable {
        struct App: Decodable {
            let version: String
            let releaseNotes: String?
            let trackViewUrl: String
        }

        let results: [App]
    }
}
