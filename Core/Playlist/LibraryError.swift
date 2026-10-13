import Foundation

enum LibraryError: LocalizedError, Equatable {
    case invalidURL
    case emptyPlaylist
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
