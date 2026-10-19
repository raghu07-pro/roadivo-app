import Foundation
import Network
import os

/// Serves `BroadcastHTTP` on the local network: the page to whoever asks, and each new frame to every browser
/// watching. A browser still receiving the last frame skips the next, so a slow car screen never builds a backlog.
/// Network delivers its events on a dispatch queue, so all of the server's state lives on that one queue.
final class FrameServer: @unchecked Sendable {
    /// One browser watching the stream; touched only on `queue`.
    private final class Viewer: @unchecked Sendable {
        let connection: NWConnection
        var isSending = true // Until the stream's header has gone out.

        init(connection: NWConnection) {
            self.connection = connection
        }
    }

    /// A few screens at most: every viewer costs the extension memory and the Wi-Fi bandwidth.
    private static let viewerLimit = 3

    private let queue = DispatchQueue(label: "com.roadivo.broadcast.server")
    private let port: NWEndpoint.Port
    private let watching = OSAllocatedUnfairLock(initialState: false)
    private let logger = Logger(subsystem: "com.roadivo.broadcast", category: "Server")
    private var listener: NWListener?
    private var viewers: [ObjectIdentifier: Viewer] = [:]

    init(port: UInt16) {
        self.port = NWEndpoint.Port(rawValue: port) ?? .http
    }

    /// Whether any browser is watching, so frames aren't encoded for nobody.
    var hasViewers: Bool {
        watching.withLock { $0 }
    }

    func start() {
        queue.async { [self] in
            do {
                let parameters = NWParameters.tcp
                parameters.allowLocalEndpointReuse = true
                let listener = try NWListener(using: parameters, on: port)
                listener.newConnectionHandler = { [weak self] connection in self?.accept(connection) }
                listener.stateUpdateHandler = { [weak self] state in
                    if case let .failed(error) = state {
                        self?.logger.error("Listener failed: \(error.localizedDescription, privacy: .public)")
                    }
                }
                listener.start(queue: queue)
                self.listener = listener
            } catch {
                logger.error("Couldn't listen: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func stop() {
        queue.async { [self] in
            listener?.cancel()
            listener = nil
            for viewer in viewers.values {
                viewer.connection.cancel()
            }
            viewers = [:]
            updateWatching()
        }
    }

    func send(_ jpeg: Data) {
        let part = BroadcastHTTP.part(jpeg)
        queue.async { [self] in
            for (id, viewer) in viewers where !viewer.isSending {
                viewer.isSending = true
                viewer.connection.send(content: part, completion: .contentProcessed { [weak self] error in
                    viewer.isSending = false
                    if error != nil {
                        self?.drop(id)
                    }
                })
            }
        }
    }

    // MARK: Connections (on `queue`)

    private func accept(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, _, error in
            guard let self, error == nil, let data else {
                connection.cancel()
                return
            }
            switch BroadcastHTTP.route(for: data) {
            case .page:
                respond(connection, with: BroadcastHTTP.pageResponse)
            case .notFound:
                respond(connection, with: BroadcastHTTP.notFoundResponse)
            case .stream:
                watch(connection)
            }
        }
    }

    private func watch(_ connection: NWConnection) {
        guard viewers.count < Self.viewerLimit else {
            connection.cancel()
            return
        }
        let viewer = Viewer(connection: connection)
        let id = ObjectIdentifier(viewer)
        viewers[id] = viewer
        updateWatching()
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed, .cancelled:
                self?.drop(id)
            default:
                break
            }
        }
        connection.send(content: BroadcastHTTP.streamHeader, completion: .contentProcessed { [weak self] error in
            viewer.isSending = false
            if error != nil {
                self?.drop(id)
            }
        })
    }

    private func respond(_ connection: NWConnection, with response: Data) {
        connection.send(content: response, completion: .contentProcessed { _ in connection.cancel() })
    }

    private func drop(_ id: ObjectIdentifier) {
        guard let viewer = viewers.removeValue(forKey: id) else { return }
        viewer.connection.cancel()
        updateWatching()
    }

    private func updateWatching() {
        let isWatched = !viewers.isEmpty
        watching.withLock { $0 = isWatched }
    }
}
