import Foundation

/// What checking one stream found.
enum StreamOutcome: Codable, Equatable, Sendable {
    case working(milliseconds: Int)
    /// It answered, but after `StreamProbe.slowAfter`.
    case slow(milliseconds: Int)
    case failed(StreamProblem)
    /// A link the check can't open (rtmp, rtsp): counted neither way.
    case unchecked
}

/// Why a stream didn't answer, in words a viewer can act on.
enum StreamProblem: Codable, Equatable, Sendable {
    case notFound
    case denied(Int)
    case serverError(Int)
    case http(Int)
    /// A 200 with a web page, typically an expired subscription or a sign-in page.
    case webPage
    case timedOut
    case noServer
    case refused
    case offline
    case other

    var description: String {
        switch self {
        case .notFound: String(appLocalized: "Not found on the server")
        case let .denied(code): String(appLocalized: "Access denied (\(code))")
        case let .serverError(code): String(appLocalized: "Server error (\(code))")
        case let .http(code): String(appLocalized: "Unexpected answer (\(code))")
        case .webPage: String(appLocalized: "Answered with a web page, not video")
        case .timedOut: String(appLocalized: "No answer within 8 seconds")
        case .noServer: String(appLocalized: "Server not found")
        case .refused: String(appLocalized: "The server refused the connection")
        case .offline: String(appLocalized: "This iPhone is offline")
        case .other: String(appLocalized: "Couldn't open the stream")
        }
    }
}

/// Opens one stream just far enough to see whether it answers.
protocol StreamProbing: Sendable {
    func probe(_ url: URL) async -> StreamOutcome
}

/// Reads only the response headers, then cancels, so a live stream is never downloaded.
struct StreamProbe: StreamProbing {
    static let timeout: TimeInterval = 8
    static let slowAfter: Duration = .seconds(3)

    var session: URLSession = .shared

    func probe(_ url: URL) async -> StreamOutcome {
        guard let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) else { return .unchecked }
        var request = URLRequest(url: url, timeoutInterval: Self.timeout)
        request.setValue("bytes=0-1023", forHTTPHeaderField: "Range")
        let clock = ContinuousClock()
        let start = clock.now
        do {
            let (bytes, response) = try await session.bytes(for: request)
            bytes.task.cancel()
            let elapsed = clock.now - start
            let milliseconds = elapsed.milliseconds
            guard let http = response as? HTTPURLResponse else {
                return elapsed > Self
                    .slowAfter ? .slow(milliseconds: milliseconds) : .working(milliseconds: milliseconds)
            }
            switch http.statusCode {
            case 200..<400:
                if http.mimeType?.lowercased() == "text/html" {
                    return .failed(.webPage)
                }
                return elapsed > Self
                    .slowAfter ? .slow(milliseconds: milliseconds) : .working(milliseconds: milliseconds)
            case 401, 403: return .failed(.denied(http.statusCode))
            case 404, 410: return .failed(.notFound)
            case 500...: return .failed(.serverError(http.statusCode))
            default: return .failed(.http(http.statusCode))
            }
        } catch let error as URLError {
            return .failed(Self.problem(for: error))
        } catch {
            return .failed(.other)
        }
    }

    static func problem(for error: URLError) -> StreamProblem {
        switch error.code {
        case .timedOut: .timedOut
        case .cannotFindHost, .dnsLookupFailed: .noServer
        case .cannotConnectToHost, .networkConnectionLost, .secureConnectionFailed: .refused
        case .notConnectedToInternet, .dataNotAllowed, .internationalRoamingOff: .offline
        default: .other
        }
    }
}

struct StreamTarget: Sendable, Equatable {
    let id: UUID
    let url: URL
}

/// Checks many streams a few at a time: IPTV providers often allow only one or two connections per
/// login, so more at once could lock the account.
struct StreamChecker: Sendable {
    let probe: any StreamProbing
    var concurrency = 2

    /// Calls `onResult` as each stream answers; cancelling the calling task stops the check.
    func check(
        _ targets: [StreamTarget],
        onResult: @escaping @MainActor @Sendable (StreamTarget, StreamOutcome) -> Void
    ) async {
        await withTaskGroup(of: (StreamTarget, StreamOutcome).self) { group in
            var remaining = targets.makeIterator()
            for _ in 0..<max(concurrency, 1) {
                guard let target = remaining.next() else { break }
                group.addTask { await (target, probe.probe(target.url)) }
            }
            while let (target, outcome) = await group.next() {
                await onResult(target, outcome)
                guard !Task.isCancelled else {
                    group.cancelAll()
                    return
                }
                if let next = remaining.next() {
                    group.addTask { await (next, probe.probe(next.url)) }
                }
            }
        }
    }
}

/// The result of checking a source's streams, saved with the source.
struct StreamCheckReport: Codable, Equatable, Sendable {
    struct Problem: Codable, Equatable, Sendable, Identifiable {
        let id: UUID
        let title: String
        let group: String
        let outcome: StreamOutcome
    }

    /// Enough to act on without the saved report growing with a 20 000-channel source.
    static let problemLimit = 300

    var checkedAt: Date
    var total: Int
    var working = 0
    var slow = 0
    var failed = 0
    var unchecked = 0
    /// Failed streams first, then slow ones.
    var problems: [Problem] = []
    var isComplete = false

    var checked: Int {
        working + slow + failed
    }

    var answered: Int {
        working + slow
    }

    mutating func record(_ item: MediaItem, _ outcome: StreamOutcome) {
        switch outcome {
        case .working: working += 1
        case .slow: slow += 1
        case .failed: failed += 1
        case .unchecked: unchecked += 1
        }
        let isProblem = switch outcome {
        case .failed, .slow: true
        default: false
        }
        guard isProblem, problems.count < Self.problemLimit else { return }
        let problem = Problem(id: item.id, title: item.title, group: item.groupTitle, outcome: outcome)
        if case .failed = outcome, let firstSlow = problems.firstIndex(where: { $0.isSlow }) {
            problems.insert(problem, at: firstSlow)
        } else {
            problems.append(problem)
        }
    }
}

extension StreamCheckReport.Problem {
    var isSlow: Bool {
        if case .slow = outcome {
            return true
        }
        return false
    }
}

extension Duration {
    var milliseconds: Int {
        Int(components.seconds) * 1000 + Int(components.attoseconds / 1_000_000_000_000_000)
    }
}
