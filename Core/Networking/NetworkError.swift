import Foundation

enum NetworkError: Error, Equatable, Sendable {
    case invalidURL
    case missingBaseURL
    case transport(String)
    case http(status: Int)
    case decoding(String)
}
