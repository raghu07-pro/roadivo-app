import Foundation
import Testing
@testable import Roadivo

/// Answers every request from a handler; the API client never reaches a server.
final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) -> (Int, Data))?

    override static func canInit(with request: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler, let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let (status, data) = handler(request)
        if let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil) {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@Suite("API client", .serialized)
struct APIClientTests {
    struct Status: Decodable, Equatable {
        let appVersion: String
    }

    private func makeClient() -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return APIClient(
            baseURL: URL(string: "https://api.example.com")!,
            session: URLSession(configuration: configuration)
        )
    }

    @Test("Builds the request from the endpoint and decodes snake_case JSON")
    func decodes() async throws {
        MockURLProtocol.handler = { request in
            #expect(request.url?.absoluteString == "https://api.example.com/v1/status?platform=ios")
            #expect(request.httpMethod == "GET")
            return (200, Data(#"{"app_version":"1.0"}"#.utf8))
        }
        let endpoint = Endpoint(path: "v1/status", queryItems: [URLQueryItem(name: "platform", value: "ios")])
        #expect(try await makeClient().send(endpoint, as: Status.self) == Status(appVersion: "1.0"))
    }

    @Test("Non-2xx responses throw an http error")
    func httpError() async {
        MockURLProtocol.handler = { _ in (503, Data()) }
        await #expect(throws: NetworkError.http(status: 503)) {
            try await makeClient().send(Endpoint(path: "v1/status"), as: Status.self)
        }
    }

    @Test("Malformed JSON throws a decoding error")
    func decodingError() async {
        MockURLProtocol.handler = { _ in (200, Data("not json".utf8)) }
        do {
            _ = try await makeClient().send(Endpoint(path: "v1/status"), as: Status.self)
            Issue.record("Expected a decoding error")
        } catch let error as NetworkError {
            if case .decoding = error {} else {
                Issue.record("Wrong error: \(error)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
