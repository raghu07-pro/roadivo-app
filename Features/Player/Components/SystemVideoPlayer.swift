import AVKit
import SwiftUI

/// The system player view: native controls, Picture in Picture, AirPlay and
/// subtitle/audio-track menus for free.
struct SystemVideoPlayer: UIViewControllerRepresentable {
    let player: AVPlayer
    /// Off when PlayCarTV draws its own controls on top.
    var showsControls = true
    /// From the connected screen's display profile.
    var gravity: AVLayerVideoGravity = .resizeAspect

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.delegate = context.coordinator
        controller.showsPlaybackControls = showsControls
        controller.allowsPictureInPicturePlayback = true
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        controller.updatesNowPlayingInfoCenter = false
        controller.entersFullScreenWhenPlaybackBegins = false
        controller.videoGravity = gravity
        context.coordinator.controller = controller
        context.coordinator.player = player
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        context.coordinator.player = player
        if controller.videoGravity != gravity {
            controller.videoGravity = gravity
        }
    }

    static func dismantleUIViewController(_ controller: AVPlayerViewController, coordinator: Coordinator) {
        coordinator.stopObserving()
    }

    /// Lets go of the player in the background, as `PlayerLayerView` does, so iOS doesn't pause it with the iPhone
    /// locked; Picture in Picture keeps it, since it shows the video.
    @MainActor
    final class Coordinator: NSObject, @preconcurrency AVPlayerViewControllerDelegate {
        weak var controller: AVPlayerViewController?
        var player: AVPlayer? {
            didSet { attach() }
        }

        private var isInPictureInPicture = false
        private var observers: [NSObjectProtocol] = []

        override init() {
            super.init()
            let center = NotificationCenter.default
            observers = [UIApplication.didEnterBackgroundNotification, UIApplication.willEnterForegroundNotification]
                .map {
                    center.addObserver(forName: $0, object: nil, queue: .main) { [weak self] note in
                        let isLeaving = note.name == UIApplication.didEnterBackgroundNotification
                        MainActor.assumeIsolated { self?.attach(isInBackground: isLeaving) }
                    }
                }
        }

        func stopObserving() {
            observers.forEach(NotificationCenter.default.removeObserver)
            observers = []
        }

        func playerViewControllerWillStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
            isInPictureInPicture = true
            attach()
        }

        func playerViewController(
            _ playerViewController: AVPlayerViewController,
            failedToStartPictureInPictureWithError error: any Error
        ) {
            isInPictureInPicture = false
            attach()
        }

        func playerViewControllerDidStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
            isInPictureInPicture = false
            attach()
        }

        private func attach(isInBackground: Bool? = nil) {
            let isLeaving = isInBackground ?? (UIApplication.shared.applicationState == .background)
            let shown = isLeaving && !isInPictureInPicture ? nil : player
            if controller?.player !== shown {
                controller?.player = shown
            }
        }
    }
}
