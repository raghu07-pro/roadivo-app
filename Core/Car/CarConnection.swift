import AVFoundation
import Observation

/// What the car can see right now: whether Roadivo is on the CarPlay screen,
/// and where audio and video are going (an AirPlay display, the car's audio).
/// The Cast to Car tab shows this instead of guessing.
@Observable
@MainActor
final class CarConnection {
    /// Set by `CarPlaySceneDelegate` when the CarPlay scene connects.
    var isCarPlayConnected = false
    /// The AirPlay receiver video is going to ("Living Room TV", "Car Display").
    private(set) var airPlayDestination: String?
    /// True when sound is going to the car (CarPlay or a USB/Bluetooth car kit).
    private(set) var isCarAudio = false

    @ObservationIgnored private var routeObserver: NSObjectProtocol?

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
        apply(AVAudioSession.sharedInstance().currentRoute.outputs.map { ($0.portType, $0.portName) })
    }

    /// Separated from `AVAudioSession` so tests can feed routes in.
    func apply(_ outputs: [(AVAudioSession.Port, String)]) {
        airPlayDestination = outputs.first { $0.0 == .airPlay }?.1
        isCarAudio = outputs.contains { $0.0 == .carAudio }
    }
}
