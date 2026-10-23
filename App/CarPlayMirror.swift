import CarPlay

/// The whole iPhone in Roadivo's CarPlay window, from its own Screen Broadcast: no address to open on the car. Shown
/// only while parked, as video is. As in CarTV: Home steps back to the tabs (Cast shows the iPhone again while it
/// still casts), End Mirroring stops the broadcast, and Fit fills the screen.
@MainActor
final class CarPlayMirror {
    private let receiver = ScreenMirrorReceiver()
    private weak var screen: CarPlayWindowController?
    private weak var root: CPMapTemplate?
    private weak var interface: CPInterfaceController?
    /// `true` when a broadcast starts; `false` when it ends, hides or comes back.
    private var onChange: ((Bool) -> Void)?
    private(set) var isStreaming = false
    private var isHidden = false
    private var shown: CarWindowState?

    func start(
        screen: CarPlayWindowController,
        root: CPMapTemplate,
        interface: CPInterfaceController,
        onChange: @escaping (Bool) -> Void
    ) {
        self.screen = screen
        self.root = root
        self.interface = interface
        self.onChange = onChange
        receiver.start { [weak self] event in
            self?.received(event)
        } onFrame: { [weak screen] frame in
            screen?.showMirrorFrame(frame)
        }
    }

    func stop() {
        receiver.stop()
        isStreaming = false
        isHidden = false
        shown = nil
        screen?.showMirror(false)
        AppEnvironment.current?.carConnection.isMirroringToCar = false
        onChange = nil
    }

    /// The Cast tab, as in CarTV: what to do on the iPhone. A list CarPlay draws itself, so a tap always shows it;
    /// once the iPhone casts, `refresh` closes it and the window shows the iPhone.
    static func castTemplate() -> CPListTemplate {
        let template = CPListTemplate(title: String(appLocalized: "Cast"), sections: [])
        template.emptyViewTitleVariants = [String(appLocalized: "Cast anything to this screen")]
        template.emptyViewSubtitleVariants = [
            String(appLocalized: "On your iPhone, open Roadivo and go to Discover › Cast to Screen to get started.")
        ]
        return template
    }

    /// Draws the window while the mirror owns it and returns true; otherwise clears it and returns false.
    func refresh(_ environment: AppEnvironment) -> Bool {
        guard isStreaming, !isHidden, let screen, let root else {
            if shown != nil {
                shown = nil
                // Behind the tabs the last picture stays, so coming back through Cast isn't black on a still screen.
                screen?.showMirror(false, keepsFrame: isStreaming)
            }
            receiver.decodesFrames = false
            return false
        }
        let parking = environment.parking
        let state = CarWindowState.make(
            isPro: environment.proAccess.isPro,
            isPlaying: true,
            isParked: parking.isParked,
            isLocationDenied: parking.isLocationDenied
        )
        // Moving, without Location or Pro, the window's card says why the iPhone isn't showing.
        screen.show(state == .video ? .home : state, playback: environment.playback)
        screen.showBrowser(false)
        screen.showMirror(state == .video)
        receiver.decodesFrames = state == .video
        guard state != shown else { return true }
        shown = state
        if let interface, interface.templates.count > 1 {
            interface.popToRootTemplate(animated: true, completion: nil)
        }
        let home = CPBarButton(image: Self.symbol("house")) { [weak self] _ in
            MainActor.assumeIsolated { self?.setHidden(true) }
        }
        let end = CPBarButton(title: String(appLocalized: "End mirroring")) { _ in
            BroadcastSignal.requestStop()
        }
        let fit = CPMapButton { [weak screen] _ in
            MainActor.assumeIsolated { screen?.toggleMirrorFill() }
        }
        fit.image = Self.symbol("arrow.up.left.and.arrow.down.right")
        let canLeave = state != .upgrade
        root.leadingNavigationBarButtons = canLeave ? [home] : []
        root.trailingNavigationBarButtons = canLeave ? [end] : []
        root.automaticallyHidesNavigationBar = state == .video
        root.hidesButtonsWithNavigationBar = state == .video
        root.mapButtons = state == .video ? [fit] : []
        return true
    }

    private static func symbol(_ name: String) -> UIImage {
        UIImage(systemName: name) ?? UIImage()
    }

    /// The Cast tab while the iPhone still casts: the window shows it again, as Home only stepped back to the tabs.
    func reveal() -> Bool {
        guard isStreaming else { return false }
        setHidden(false)
        return true
    }

    private func setHidden(_ hidden: Bool) {
        isHidden = hidden
        onChange?(false)
    }

    private func received(_ event: ScreenMirrorReceiver.Event) {
        isStreaming = event == .started
        isHidden = false
        AppEnvironment.current?.carConnection.isMirroringToCar = isStreaming
        CarPlayTrace.write("mirror \(event)")
        onChange?(event == .started)
    }
}
