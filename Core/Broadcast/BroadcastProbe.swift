import Foundation
import Network
import os

/// Whether this iPhone's Screen Broadcast is running: PlayCarTV's extension answers its page on the loopback address.
enum BroadcastProbe {
    /// A broadcast answers at once; anything slower counts as none, so Cast to Screen never waits on it.
    private static let timeout = Duration.seconds(2)

    static func isRunning(port: UInt16 = BroadcastHTTP.port, path: String = "/\(BroadcastHTTP.code)") async -> Bool {
        let endpoint = NWEndpoint.Port(rawValue: port) ?? .http
        let connection = NWConnection(host: .ipv4(.loopback), port: endpoint, using: .tcp)
        let answered = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            let isDone = OSAllocatedUnfairLock(initialState: false)
            let finish: @Sendable (Bool) -> Void = { answer in
                guard isDone.withLock({ done in defer { done = true }
                    return !done }) else { return }
                continuation.resume(returning: answer)
            }
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    ask(connection, for: path, then: finish)
                case .waiting, .failed, .cancelled:
                    finish(false) // Refused: nothing listens, so no broadcast.
                default:
                    break
                }
            }
            connection.start(queue: .global(qos: .utility))
            Task {
                try? await Task.sleep(for: timeout) // Never cancelled; only bounds the wait.
                finish(false)
            }
        }
        connection.cancel()
        return answered
    }

    private static func ask(
        _ connection: NWConnection,
        for path: String,
        then finish: @escaping @Sendable (Bool) -> Void
    ) {
        let request = Data("GET \(path) HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n".utf8)
        connection.send(content: request, completion: .contentProcessed { error in
            guard error == nil else { return finish(false) }
            connection.receive(minimumIncompleteLength: 12, maximumLength: 64) { data, _, _, _ in
                let answer = data.flatMap { String(bytes: $0, encoding: .utf8) } ?? ""
                finish(answer.hasPrefix("HTTP/1.1 200"))
            }
        })
    }
}
