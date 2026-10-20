import AVFoundation
import SwiftUI

/// A bare `AVPlayerLayer` for custom-chrome surfaces (Car Mode, the mini player).
struct VideoSurface: UIViewRepresentable {
    let player: AVPlayer
    var gravity: AVLayerVideoGravity = .resizeAspect

    func makeUIView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        view.backgroundColor = .black
        view.player = player
        view.playerLayer.videoGravity = gravity
        return view
    }

    func updateUIView(_ view: PlayerLayerView, context: Context) {
        view.player = player
        view.playerLayer.videoGravity = gravity
    }

    static func dismantleUIView(_ view: PlayerLayerView, coordinator: ()) {
        view.player = nil
        view.stopObserving()
    }
}

/// Shows `player` only while the app is on screen. iOS pauses a player whose video is showing when the app leaves the
/// screen, so in the background the layer lets go and the sound plays on: in the car, with the iPhone locked.
final class PlayerLayerView: UIView {
    override static var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        // layerClass guarantees the type; the fallback never runs.
        layer as? AVPlayerLayer ?? AVPlayerLayer()
    }

    var player: AVPlayer? {
        didSet { attach() }
    }

    private var observers: [NSObjectProtocol] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        observe()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        observe()
    }

    func stopObserving() {
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
    }

    private func observe() {
        let center = NotificationCenter.default
        observers = [UIApplication.didEnterBackgroundNotification, UIApplication.willEnterForegroundNotification].map {
            center.addObserver(forName: $0, object: nil, queue: .main) { [weak self] note in
                let isLeaving = note.name == UIApplication.didEnterBackgroundNotification
                MainActor.assumeIsolated { self?.attach(isInBackground: isLeaving) }
            }
        }
    }

    /// Also when the view is made in the background, e.g. playback started from CarPlay with the iPhone locked.
    private func attach(isInBackground: Bool? = nil) {
        let isHidden = isInBackground ?? (UIApplication.shared.applicationState == .background)
        let shown = isHidden ? nil : player
        if playerLayer.player !== shown {
            playerLayer.player = shown
        }
    }
}
