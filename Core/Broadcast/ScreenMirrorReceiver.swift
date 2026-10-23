import Network
import os
import UIKit

/// The CarPlay window's mirror: reads this iPhone's own Screen Broadcast over loopback, so the car shows the whole
/// iPhone with no address to open. Network delivers its events on a queue, so the state lives on that one queue.
final class ScreenMirrorReceiver: @unchecked Sendable {
    enum Event: Sendable {
        /// The first frame of a broadcast arrived.
        case started
        /// The broadcast ended, or Roadivo's extension stopped answering.
        case ended
    }

    /// A broadcast that hasn't started yet, or the extension binding its port, is looked for again this often.
    private static let retryInterval = DispatchTimeInterval.seconds(2)

    private let queue = DispatchQueue(label: "com.roadivo.mirror")
    private let port: NWEndpoint.Port
    private let path: String
    private let logger = Logger(subsystem: "com.roadivo", category: "Mirror")
    private var isRunning = false
    private var isStreaming = false
    private var connection: NWConnection?
    private var parser = MJPEGParser()
    private var onEvent: (@MainActor @Sendable (Event) -> Void)?
    private var onFrame: (@MainActor @Sendable (UIImage) -> Void)?
    /// Frames are only decoded while the window shows them; off, the stream still tells when the broadcast ends.
    private let decodes = OSAllocatedUnfairLock(initialState: false)
    /// The newest decoded frame waiting for the main actor; a slow screen skips to it rather than queueing up.
    private let latest = OSAllocatedUnfairLock<UIImage?>(initialState: nil)

    init(port: UInt16 = BroadcastHTTP.port, path: String = "/\(BroadcastHTTP.code)/stream") {
        self.port = NWEndpoint.Port(rawValue: port) ?? .http
        self.path = path
    }

    var decodesFrames: Bool {
        get { decodes.withLock { $0 } }
        set { decodes.withLock { $0 = newValue } }
    }

    /// Looks for a broadcast until `stop()`, and again after each one ends.
    func start(
        onEvent: @escaping @MainActor @Sendable (Event) -> Void,
        onFrame: @escaping @MainActor @Sendable (UIImage) -> Void
    ) {
        queue.async { [self] in
            guard !isRunning else { return }
            isRunning = true
            self.onEvent = onEvent
            self.onFrame = onFrame
            connect()
        }
    }

    func stop() {
        queue.async { [self] in
            isRunning = false
            if let connection {
                end(connection)
            }
            onEvent = nil
            onFrame = nil
        }
    }
}

// MARK: - Connection (on `queue`)

private extension ScreenMirrorReceiver {
    func connect() {
        guard isRunning, connection == nil else { return }
        parser = MJPEGParser()
        let connection = NWConnection(host: .ipv4(.loopback), port: port, using: .tcp)
        self.connection = connection
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            guard let self, let connection else { return }
            switch state {
            case .ready:
                request(on: connection)
            case .waiting, .failed:
                // Refused: no broadcast is running yet.
                end(connection)
            default:
                break
            }
        }
        connection.start(queue: queue)
    }

    func request(on connection: NWConnection) {
        let request = "GET \(path) HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n"
        connection.send(content: Data(request.utf8), completion: .contentProcessed { [weak self] error in
            guard let self else { return }
            if error == nil {
                receive(on: connection)
            } else {
                end(connection)
            }
        })
    }

    func receive(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 512 * 1024) { [weak self] data, _, done, error in
            guard let self, connection === self.connection else { return }
            for frame in parser.append(data ?? Data()) {
                deliver(frame)
            }
            if done || error != nil || parser.hasFailed {
                if parser.hasFailed {
                    logger.error("The broadcast's stream couldn't be read")
                }
                end(connection)
            } else {
                receive(on: connection)
            }
        }
    }

    func deliver(_ jpeg: Data) {
        if !isStreaming {
            isStreaming = true
            report(.started)
        }
        guard decodesFrames, let image = UIImage(data: jpeg)?.preparingForDisplay(), let onFrame else { return }
        let wasWaiting = latest.withLock { slot in
            defer { slot = image }
            return slot != nil
        }
        guard !wasWaiting else { return }
        Task { @MainActor [latest] in
            if let image = latest.withLock({ slot in defer { slot = nil }
                return slot }) {
                onFrame(image)
            }
        }
    }

    func end(_ connection: NWConnection) {
        guard connection === self.connection else { return }
        connection.stateUpdateHandler = nil
        connection.forceCancel()
        self.connection = nil
        if isStreaming {
            isStreaming = false
            report(.ended)
        }
        guard isRunning else { return }
        queue.asyncAfter(deadline: .now() + Self.retryInterval) { [weak self] in self?.connect() }
    }

    func report(_ event: Event) {
        guard let onEvent else { return }
        Task { @MainActor in onEvent(event) }
    }
}
