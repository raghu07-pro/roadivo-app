#if DEBUG
    import UIKit

    /// The iPhone's screen from Roadivo's Screen Broadcast on the plain car window: `CarPlayMirror`'s receiver
    /// without its templates. Shown only while parked, as video is.
    @MainActor
    final class CarScreenMirror {
        private let receiver = ScreenMirrorReceiver()
        private weak var stage: CarPlayWindowController?
        /// `true` when a broadcast starts; `false` when it ends.
        private var onChange: ((Bool) -> Void)?
        private(set) var isStreaming = false
        /// Home stepped back to the tabs while the iPhone still casts.
        var isHidden = false

        /// The mirror has the screen.
        var isShown: Bool {
            isStreaming && !isHidden
        }

        func start(stage: CarPlayWindowController, onChange: @escaping (Bool) -> Void) {
            self.stage = stage
            self.onChange = onChange
            receiver.start { [weak self] event in
                self?.received(event)
            } onFrame: { [weak stage] frame in
                stage?.showMirrorFrame(frame)
            }
        }

        func stop() {
            receiver.stop()
            isStreaming = false
            isHidden = false
            stage?.showMirror(false)
            AppEnvironment.current?.carConnection.isMirroringToCar = false
            onChange = nil
        }

        /// The picture while parked; moving, without Location or Pro, the window's card says why it's off.
        func show(_ state: CarWindowState, playback: PlaybackController) {
            stage?.show(state == .video ? .home : state, playback: playback)
            stage?.showBrowser(false)
            stage?.showMirror(state == .video)
            receiver.decodesFrames = state == .video
        }

        /// Behind the tabs the last picture stays, so coming back through Cast isn't black on a still screen.
        func hide() {
            stage?.showMirror(false, keepsFrame: isStreaming)
            receiver.decodesFrames = false
        }

        private func received(_ event: ScreenMirrorReceiver.Event) {
            isStreaming = event == .started
            isHidden = false
            AppEnvironment.current?.carConnection.isMirroringToCar = isStreaming
            CarPlayTrace.write("screen mirror \(event)")
            onChange?(isStreaming)
        }
    }
#endif
