import CoreLocation
import Observation

/// The iPhone's location while Directions is in use. Nothing is stored or sent anywhere but Apple Maps.
@MainActor
@Observable
final class DeviceLocation: NSObject, LocationProviding {
    private(set) var status: LocationStatus = .notAsked
    private(set) var lastCoordinate: Coordinate?
    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private var waitingForAnswer: [CheckedContinuation<Void, Never>] = []
    @ObservationIgnored private var waitingForFix: [CheckedContinuation<Coordinate?, Never>] = []
    /// A fix this recent is reused instead of asking for a new one.
    private static let freshness: TimeInterval = 120
    /// Guidance skips fixes vaguer than this, in metres, so a poor one doesn't look like leaving the route.
    private static let guidanceAccuracy: Double = 50

    override init() {
        super.init()
        // Street level is plenty for a route's start, and quicker to get.
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.delegate = self
        status = Self.status(manager.authorizationStatus)
        lastCoordinate = manager.location.map { Coordinate($0.coordinate) }
    }

    func requestAccess() {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
    }

    func currentCoordinate() async -> Coordinate? {
        if status == .notAsked {
            requestAccess()
            await withCheckedContinuation { waitingForAnswer.append($0) }
        }
        guard status == .allowed else { return nil }
        if let recent = manager.location, -recent.timestamp.timeIntervalSinceNow < Self.freshness {
            return Coordinate(recent.coordinate)
        }
        return await withCheckedContinuation { continuation in
            waitingForFix.append(continuation)
            if waitingForFix.count == 1 {
                manager.requestLocation()
            }
        }
    }

    func updates() -> AsyncStream<Coordinate> {
        AsyncStream { continuation in
            let task = Task { @MainActor [weak self] in
                do {
                    for try await update in CLLocationUpdate.liveUpdates(.automotiveNavigation) {
                        guard let fix = update.location, fix.horizontalAccuracy >= 0,
                              fix.horizontalAccuracy <= Self.guidanceAccuracy
                        else { continue }
                        let coordinate = Coordinate(fix.coordinate)
                        self?.lastCoordinate = coordinate
                        continuation.yield(coordinate)
                    }
                } catch {
                    // Core Location ended the updates; guidance keeps its last fix until it's started again.
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func answered(_ authorization: CLAuthorizationStatus) {
        status = Self.status(authorization)
        guard status != .notAsked else { return }
        let waiting = waitingForAnswer
        waitingForAnswer = []
        waiting.forEach { $0.resume() }
        if status == .denied {
            finish(nil)
        }
    }

    private func finish(_ coordinate: Coordinate?) {
        if let coordinate {
            lastCoordinate = coordinate
        }
        let waiting = waitingForFix
        waitingForFix = []
        waiting.forEach { $0.resume(returning: coordinate) }
    }

    private static func status(_ authorization: CLAuthorizationStatus) -> LocationStatus {
        switch authorization {
        case .authorizedAlways, .authorizedWhenInUse: .allowed
        case .denied, .restricted: .denied
        case .notDetermined: .notAsked
        @unknown default: .denied
        }
    }
}

/// The manager was made on the main thread, so it calls back there.
extension DeviceLocation: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let authorization = manager.authorizationStatus
        MainActor.assumeIsolated { answered(authorization) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let coordinate = locations.last.map { Coordinate($0.coordinate) }
        MainActor.assumeIsolated { finish(coordinate) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        MainActor.assumeIsolated { finish(nil) }
    }
}
