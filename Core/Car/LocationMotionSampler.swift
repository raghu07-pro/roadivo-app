import CoreLocation
import Observation

/// The car's motion from the iPhone's location while CarPlay shows Roadivo. Nothing is stored or sent (DECISIONS 152).
@Observable
@MainActor
final class LocationMotionSampler: NSObject, MotionSampling {
    private(set) var isLocationDenied = false
    @ObservationIgnored private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        isLocationDenied = Self.isDenied(manager.authorizationStatus)
    }

    func requestAccess() {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
    }

    func samples() -> AsyncStream<MotionSample> {
        AsyncStream { continuation in
            let task = Task { @MainActor in
                do {
                    for try await update in CLLocationUpdate.liveUpdates(.automotiveNavigation) {
                        continuation.yield(Self.sample(from: update))
                    }
                } catch {
                    // Core Location ended the updates; the stream's end counts as not parked.
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func sample(from update: CLLocationUpdate) -> MotionSample {
        var isStationary = update.isStationary
        if #available(iOS 18, *) {
            isStationary = update.stationary
        }
        let fix = update.location
        return MotionSample.classify(speed: fix?.speed, speedAccuracy: fix?.speedAccuracy, isStationary: isStationary)
    }

    private static func isDenied(_ status: CLAuthorizationStatus) -> Bool {
        status == .denied || status == .restricted
    }
}

/// The manager was made on the main thread, so it calls back there.
extension LocationMotionSampler: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        MainActor.assumeIsolated { isLocationDenied = Self.isDenied(status) }
    }
}
