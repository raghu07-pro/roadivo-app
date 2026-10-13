import Foundation

enum LibraryError: LocalizedError, Equatable {
    case invalidURL
    case emptyPlaylist
    /// The link answered with a web page or JSON, not a playlist.
    case webPage
    /// The link is a video or audio stream, not a playlist.
    case mediaFile
    /// The download passed the size a playlist can sensibly have.
    case tooLarge
    case unreadable
    case httpStatus(Int)
    case download(String)
    case notFound

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            String(appLocalized: "That doesn't look like a playlist link. Check it starts with http:// or https://.")
        case .emptyPlaylist:
            String(appLocalized: "We couldn't find any channels or videos in that playlist.")
        case .webPage:
            String(
                appLocalized: """
                That link opened a web page, not a playlist. On hotel or café Wi-Fi, sign in to the network \
                first. Otherwise check the link and that your subscription is still active.
                """
            )
        case .mediaFile:
            String(
                appLocalized: "That link is a video, not a playlist. Paste your provider's M3U playlist link instead."
            )
        case .tooLarge:
            String(
                appLocalized: """
                That playlist is too large to load on iPhone. Ask your provider for a smaller list, such as \
                live TV only.
                """
            )
        case .unreadable:
            String(appLocalized: "That file couldn't be read as a playlist.")
        case let .httpStatus(code):
            String(appLocalized: "The server answered with error \(code). Check the link and try again.")
        case let .download(reason):
            String(appLocalized: "The playlist couldn't be downloaded. \(reason)")
        case .notFound:
            String(appLocalized: "That item is no longer in your library.")
        }
    }
}
