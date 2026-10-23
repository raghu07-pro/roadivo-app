import Foundation

/// Native CarPlay search can open YouTube results without interacting with the webpage's input field.
enum CarBrowserSiteSearch {
    static func url(for query: String, on page: URL?) -> URL? {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, let host = page?.host()?.lowercased(),
              host == "youtube.com" || host.hasSuffix(".youtube.com") else { return nil }
        var components = URLComponents(string: "https://m.youtube.com/results")
        components?.queryItems = [URLQueryItem(name: "search_query", value: query)]
        return components?.url
    }
}
