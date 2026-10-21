import Foundation

/// What the CarPlay Browser's search offers for what's typed (DECISIONS 134): the web address itself, the
/// matching sites, then a web search. Each opens in the iPhone's Browser; CarPlay can't show a page.
enum BrowserSearch {
    enum Result: Equatable {
        case address(URL)
        case site(BrowserSite)
        /// Words, searched on the web.
        case search(query: String, url: URL)

        var url: URL {
            switch self {
            case let .address(url), let .search(_, url): url
            case let .site(site): site.url
            }
        }

        /// The row's name, which the "open on your iPhone" alert repeats.
        var title: String {
            switch self {
            case let .address(url): WebAddress.displayName(of: url)
            case let .site(site): site.name
            case let .search(query, _): query
            }
        }

        var detail: String {
            switch self {
            case let .address(url): url.absoluteString
            case let .site(site): WebAddress.displayName(of: site.url)
            case let .search(_, url): WebAddress.displayName(of: url)
            }
        }
    }

    /// Every site while nothing is typed; at most `limit` rows, as the car allows.
    static func results(for input: String, sites: [BrowserSite] = BrowserSite.all, limit: Int) -> [Result] {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return Array(sites.map(Result.site).prefix(max(1, limit))) }
        let matches = sites.filter {
            $0.name.localizedCaseInsensitiveContains(text)
                || WebAddress.displayName(of: $0.url).localizedCaseInsensitiveContains(text)
        }
        var results: [Result] = []
        // A typed address that is one of the sites shows as that site, with its icon, instead.
        if let address = WebAddress.address(for: text),
           !matches.contains(where: { WebAddress.displayName(of: $0.url) == WebAddress.displayName(of: address) }) {
            results.append(.address(address))
        }
        results += matches.map(Result.site)
        if let search = WebAddress.searchURL(for: text) {
            results.append(.search(query: text, url: search))
        }
        // The web search is the last row; it stays when the list is cut.
        guard results.count > limit, let last = results.last else { return results }
        return Array(results.prefix(max(0, limit - 1))) + [last]
    }
}
