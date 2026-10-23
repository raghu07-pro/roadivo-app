import Foundation
import Network
import os

/// Stands in for the broadcast extension's `FrameServer` on a free loopback port: answers each known path once.
final class LoopbackBroadcast: @unchecked Sendable {
    private let listener: NWListener
    private let queue = DispatchQueue(label: "com.roadivo.tests.loopback")
    private let answers: [String: Data]
    private var connections: [NWConnection] = []

    init(answers: [String: Data]) throws {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: .any)
        listener = try NWListener(using: parameters)
        self.answers = answers
    }

    func start() async -> UInt16 {
        await withCheckedContinuation { continuation in
            let isWaiting = OSAllocatedUnfairLock(initialState: true)
            listener.stateUpdateHandler = { [listener] state in
                guard case .ready = state, isWaiting.withLock({ waiting in defer { waiting = false }
                    return waiting })
                else { return }
                continuation.resume(returning: listener.port?.rawValue ?? 0)
            }
            listener.newConnectionHandler = { [weak self] connection in self?.serve(connection) }
            listener.start(queue: queue)
        }
    }

    /// Drops every connection, as the extension does when the broadcast stops.
    func endBroadcast() {
        queue.async { [self] in
            connections.forEach { $0.forceCancel() }
            connections = []
        }
    }

    func stop() {
        endBroadcast()
        listener.cancel()
    }

    private func serve(_ connection: NWConnection) {
        connections.append(connection)
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8 * 1024) { [answers] data, _, _, _ in
            let request = data.flatMap { String(bytes: $0, encoding: .utf8) } ?? ""
            let path = request.split(separator: " ").dropFirst().first.map(String.init) ?? ""
            guard request.hasPrefix("GET "), let answer = answers[path] else { return connection.cancel() }
            connection.send(content: answer, completion: .contentProcessed { _ in })
        }
    }
}
