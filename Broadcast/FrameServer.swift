import Foundation
import Network
import os

/// Serves `BroadcastHTTP` on the local network: the page to whoever asks, and each new frame to every browser
/// watching. A browser still receiving the last frame skips the next, so a slow car screen never builds a backlog.
/// Network delivers its events on a dispatch queue, so all of the server's state lives on that one queue.
final class FrameServer: @unchecked Sendable {
    /// One browser watching the stream; touched only on `queue`. File-private for the extensions below.
    fileprivate final class Viewer: @unchecked Sendable {
        let connection: NWConnection
        var isSending = false
        /// When the latest send began: a send stuck too long means a dead peer, an old one means a still screen.
        var sentAt = ContinuousClock.now

        init(connection: NWConnection) {
            self.connection = connection
        }
    }

    /// A connection whose request line hasn't arrived yet.
    fileprivate struct Pending {
        let connection: NWConnection
        let openedAt: ContinuousClock.Instant
    }

    /// A few screens at most: every viewer costs the extension memory and the Wi-Fi bandwidth.
    private static let viewerLimit = 3
    /// Browsers send their request at once, so a silent connection is cut off rather than holding a slot.
    private static let pendingLimit = 16
    private static let requestTimeout = Duration.seconds(5)
    /// A send this late means the car left without closing; keepalive alone takes longer to notice.
    private static let sendTimeout = Duration.seconds(5)
    /// A still screen brings no new frames, so the last is sent again: the picture stays up and dead peers show.
    private static let refreshInterval = Duration.seconds(2)
    /// The previous broadcast's process may hold the port for a moment.
    private static let bindRetries = 3
    /// Different wrong paths from one device before it's refused for the rest of the broadcast, so the code can't be
    /// guessed. Distinct paths, because a tab left on an old code retries the same one every second.
    private static let missLimit = 10

    private let queue = DispatchQueue(label: "com.roadivo.broadcast.server")
    private let port: NWEndpoint.Port
    private let code: String
    private let readiness = OSAllocatedUnfairLock(initialState: false)
    private let logger = Logger(subsystem: "com.roadivo.broadcast", category: "Server")
    private var isRunning = false
    private var onFailure: (@Sendable () -> Void)?
    private var listener: NWListener?
    private var bindFailures = 0
    private var timer: DispatchSourceTimer?
    private var pending: [Pending] = []
    private var viewers: [Viewer] = []
    /// The newest frame as a stream part: a browser that joins on a still screen gets it at once, not black.
    private var lastPart: Data?
    /// Each device's wrong paths, as hashes to stay small.
    private var misses: [Data: Set<Int>] = [:]

    init(port: UInt16, code: String) {
        self.port = NWEndpoint.Port(rawValue: port) ?? .http
        self.code = code
    }

    /// Whether a browser is waiting for its next frame; if none is, a frame a second keeps `lastPart` current.
    var isViewerReady: Bool {
        readiness.withLock { $0 }
    }

    /// `onFailure` runs (off the server's queue) if the port still can't be opened after a few tries.
    func start(onFailure: @escaping @Sendable () -> Void) {
        queue.async { [self] in
            guard !isRunning, listener == nil else { return }
            isRunning = true
            self.onFailure = onFailure
            bindFailures = 0
            listen()
            startTimer()
        }
    }

    /// Resets every browser rather than closing gracefully, so the page's `onerror` fires and it reconnects.
    /// Synchronous, because the extension may exit as soon as the broadcast finishes.
    func stop() {
        queue.sync {
            isRunning = false
            onFailure = nil
            timer?.cancel()
            timer = nil
            listener?.cancel()
            listener = nil
            for request in pending {
                request.connection.forceCancel()
            }
            pending = []
            for viewer in viewers {
                viewer.connection.forceCancel()
            }
            viewers = []
            lastPart = nil
            misses = [:]
            updateReadiness()
        }
    }

    /// Keeps the frame for browsers that join later, and sends it to every browser ready for one.
    func send(_ jpeg: Data) {
        let part = BroadcastHTTP.part(jpeg)
        queue.async { [self] in
            guard isRunning else { return }
            lastPart = part
            for viewer in viewers where !viewer.isSending {
                deliver(part, to: viewer)
            }
        }
    }
}

// MARK: - Listening (on `queue`)

private extension FrameServer {
    /// TCP that notices a car that drove off: keepalive probes after 5 s of quiet, the connection gone after 10 s.
    static func parameters() -> NWParameters {
        let tcp = NWProtocolTCP.Options()
        tcp.noDelay = true
        tcp.enableKeepalive = true
        tcp.keepaliveIdle = 5
        tcp.keepaliveInterval = 2
        tcp.keepaliveCount = 3
        tcp.connectionDropTime = 10
        let parameters = NWParameters(tls: nil, tcp: tcp)
        parameters.allowLocalEndpointReuse = true
        // The car is on the Wi-Fi or the hotspot; the screen is never offered on the cellular network.
        parameters.prohibitedInterfaceTypes = [.cellular]
        return parameters
    }

    func listen() {
        guard isRunning, listener == nil else { return }
        let newListener: NWListener
        do {
            newListener = try NWListener(using: Self.parameters(), on: port)
        } catch {
            logger.error("Couldn't listen: \(error.localizedDescription, privacy: .public)")
            retryListening()
            return
        }
        newListener.newConnectionHandler = { [weak self] connection in self?.accept(connection) }
        newListener.stateUpdateHandler = { [weak self, weak newListener] state in
            guard let self, let newListener, newListener === listener else { return }
            switch state {
            case .ready:
                bindFailures = 0
            case let .failed(error):
                // Also mid-broadcast (the network changed): a new listener takes over on the same port.
                logger.error("Listener failed: \(error.localizedDescription, privacy: .public)")
                newListener.cancel()
                listener = nil
                retryListening()
            default:
                break
            }
        }
        listener = newListener
        newListener.start(queue: queue)
    }

    /// Tries again in half a second; after a few failures the broadcast ends with a message, not a dead address.
    func retryListening() {
        bindFailures += 1
        guard bindFailures > Self.bindRetries else {
            queue.asyncAfter(deadline: .now() + .milliseconds(500)) { [weak self] in self?.listen() }
            return
        }
        logger.fault("Gave up listening on the broadcast port")
        isRunning = false
        let report = onFailure
        // Off the queue: ending the broadcast calls `stop()`, which waits on it.
        DispatchQueue.global().async { report?() }
    }

    func startTimer() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + .seconds(1), repeating: .seconds(1), leeway: .milliseconds(250))
        timer.setEventHandler { [weak self] in self?.tidy() }
        timer.resume()
        self.timer = timer
    }

    /// Once a second: ends silent requests and stuck sends, and repeats the last frame to browsers left waiting.
    func tidy() {
        let now = ContinuousClock.now
        for request in pending where now - request.openedAt >= Self.requestTimeout {
            close(request.connection)
        }
        for viewer in viewers {
            if viewer.isSending, now - viewer.sentAt >= Self.sendTimeout {
                logger.notice("Dropped a viewer that stopped receiving")
                drop(viewer)
            } else if !viewer.isSending, now - viewer.sentAt >= Self.refreshInterval, let lastPart {
                deliver(lastPart, to: viewer)
            }
        }
    }
}

// MARK: - Connections (on `queue`)

private extension FrameServer {
    func accept(_ connection: NWConnection) {
        guard let address = Self.address(of: connection.endpoint), BroadcastPeer.isLocal(address),
              misses[address, default: []].count < Self.missLimit else {
            connection.cancel()
            return
        }
        if pending.count >= Self.pendingLimit, let oldest = pending.first {
            close(oldest.connection)
        }
        pending.append(Pending(connection: connection, openedAt: .now))
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            guard case .failed = state, let connection else { return }
            self?.close(connection)
        }
        connection.start(queue: queue)
        readRequest(on: connection, buffer: Data())
    }

    /// Reads until the request line is complete, at most `BroadcastHTTP.requestLimit` bytes.
    func readRequest(on connection: NWConnection, buffer: Data) {
        let room = BroadcastHTTP.requestLimit - buffer.count
        connection.receive(minimumIncompleteLength: 1, maximumLength: room) { [weak self] data, _, isDone, error in
            guard let self, pending.contains(where: { $0.connection === connection }) else { return }
            var request = buffer
            request.append(data ?? Data())
            if BroadcastHTTP.requestLine(in: request) != nil {
                route(connection, request: request)
            } else if error != nil || isDone || request.count >= BroadcastHTTP.requestLimit {
                close(connection)
            } else {
                readRequest(on: connection, buffer: request)
            }
        }
    }

    func route(_ connection: NWConnection, request: Data) {
        pending.removeAll { $0.connection === connection }
        switch BroadcastHTTP.route(for: request, code: code) {
        case .page:
            respond(connection, with: BroadcastHTTP.pageResponse(code: code))
        case .stream:
            watch(connection)
        case .notFound:
            if let address = Self.address(of: connection.endpoint) {
                misses[address, default: []].insert(BroadcastHTTP.path(of: request)?.hashValue ?? 0)
            }
            respond(connection, with: BroadcastHTTP.notFoundResponse)
        }
    }

    /// The newest browser always gets in: at the limit the oldest goes, most likely a car that left without closing.
    func watch(_ connection: NWConnection) {
        if viewers.count >= Self.viewerLimit, let oldest = viewers.first {
            drop(oldest)
        }
        let viewer = Viewer(connection: connection)
        viewers.append(viewer)
        connection.stateUpdateHandler = { [weak self, weak viewer] state in
            switch state {
            case .failed, .cancelled:
                if let viewer {
                    self?.drop(viewer)
                }
            default:
                break
            }
        }
        awaitClose(of: viewer)
        var opening = BroadcastHTTP.streamHeader
        opening.append(lastPart ?? Data())
        deliver(opening, to: viewer)
    }

    /// A browser sends nothing after its request, so a read that ends means the page was closed.
    func awaitClose(of viewer: Viewer) {
        let connection = viewer.connection
        // Holds the viewer until the read ends, which `drop`'s reset always brings about.
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1024) { [weak self] _, _, isDone, error in
            guard let self else { return }
            if isDone || error != nil {
                drop(viewer)
            } else {
                awaitClose(of: viewer)
            }
        }
    }

    func deliver(_ data: Data, to viewer: Viewer) {
        viewer.isSending = true
        viewer.sentAt = .now
        updateReadiness()
        viewer.connection.send(content: data, completion: .contentProcessed { [weak self] error in
            viewer.isSending = false
            if error != nil {
                self?.drop(viewer)
            } else {
                self?.updateReadiness()
            }
        })
    }

    func respond(_ connection: NWConnection, with response: Data) {
        connection.send(content: response, completion: .contentProcessed { _ in connection.cancel() })
    }

    /// Ends a connection that never became a viewer.
    func close(_ connection: NWConnection) {
        pending.removeAll { $0.connection === connection }
        connection.cancel()
    }

    /// A reset, not a graceful close: the stream never ends on its own, and a dead peer would hold it open.
    func drop(_ viewer: Viewer) {
        guard let index = viewers.firstIndex(where: { $0 === viewer }) else { return }
        viewers.remove(at: index)
        viewer.connection.forceCancel()
        updateReadiness()
    }

    func updateReadiness() {
        let isReady = viewers.contains { !$0.isSending }
        readiness.withLock { $0 = isReady }
    }

    /// The peer's IPv4 or IPv6 address bytes; nil for a name, which a browser on the local network never is.
    static func address(of endpoint: NWEndpoint) -> Data? {
        guard case let .hostPort(host, _) = endpoint else { return nil }
        switch host {
        case let .ipv4(address):
            return address.rawValue
        case let .ipv6(address):
            return address.rawValue
        default:
            return nil
        }
    }
}
