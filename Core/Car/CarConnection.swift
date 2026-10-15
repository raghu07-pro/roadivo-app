import AVFoundation
import Observation

/// What the car sees right now: whether Roadivo is on CarPlay, and where audio and video go
/// (an AirPlay display, the car's audio). The Cast to Car tab shows this.
@Observable
@MainActor
final class CarConnection {
    /// Set by `CarPlaySceneDelegate` when the CarPlay scene connects.
    var isCarPlayConnected = false
    /// The AirPlay receiver video is going to ("Living Room TV", "Car Display").
    private(set) var airPlayDestination: String?
    /// True when sound goes to the car over CarPlay. iOS reports a Bluetooth car kit like headphones.
    private(set) var isCarAudio = false

    @ObservationIgnored private var routeObserver: NSObjectProtocol?
    /// UI tests stand in for a car's audio route, which a simulator can't have.
    @ObservationIgnored var simulatedOutputs: [(AVAudioSession.Port, String)]?

    func start() {
        guard routeObserver == nil else { return }
        refreshRoute()
        routeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshRoute() }
        }
    }

    func refreshRoute() {
        apply(simulatedOutputs ?? AVAudioSession.sharedInstance().currentRoute.outputs
            .map { ($0.portType, $0.portName) })
    }

    /// Separated from `AVAudioSession` so tests can feed routes in.
    func apply(_ outputs: [(AVAudioSession.Port, String)]) {
        airPlayDestination = outputs.first { $0.0 == .airPlay }?.1
        isCarAudio = outputs.contains { $0.0 == .carAudio }
    }
}
