import AVKit
import SwiftUI

/// The system player view: native controls, Picture in Picture, AirPlay and
/// subtitle/audio-track menus for free.
struct SystemVideoPlayer: UIViewControllerRepresentable {
    let player: AVPlayer
    /// Off when Roadivo draws its own controls on top.
    var showsControls = true
    /// From the connected screen's display profile.
    var gravity: AVLayerVideoGravity = .resizeAspect

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = showsControls
        controller.allowsPictureInPicturePlayback = true
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        controller.updatesNowPlayingInfoCenter = false
        controller.entersFullScreenWhenPlaybackBegins = false
        controller.videoGravity = gravity
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        if controller.player !== player {
            controller.player = player
        }
        if controller.videoGravity != gravity {
            controller.videoGravity = gravity
        }
    }
}
