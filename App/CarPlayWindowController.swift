import AVFoundation
import SwiftUI

/// Roadivo's CarPlay window (DECISIONS 152, 154): the video while parked with Car Mode's progress bar, otherwise the
/// road and one line. CarPlay's buttons sit on top; a drag across the window moves the video's place.
final class CarPlayWindowController: UIViewController {
    private let video = PlayerLayerView()
    private let card = UIHostingController(rootView: CarWindowCard(content: CarWindowCard.Content()))
    private let progress = UIHostingController(rootView: CarWindowProgress())
    /// The bar stops short of CarPlay's map buttons once the window's guide for them is known.
    private var progressTrailing: NSLayoutConstraint?
    private weak var playback: PlaybackController?
    /// A drag under way: the bar shows where it will land.
    private var scrub: CarScrub?
    /// Refreshes the bar while the video shows: pushed, as observed changes didn't redraw it on the car's screen.
    private var ticker: Timer?
    /// Each minute while the car is connected, for the road's hour (`updateMoment`).
    private var clock: Timer?
    private var browser: CarBrowserController?
    /// The whole iPhone from Screen Broadcast, over everything else while parked.
    private let mirror = UIImageView()

    func installBrowser(_ browser: CarBrowserController) {
        loadViewIfNeeded()
        self.browser = browser
        addChild(browser)
        browser.view.translatesAutoresizingMaskIntoConstraints = false
        browser.view.isHidden = true
        view.addSubview(browser.view)
        NSLayoutConstraint.activate([
            browser.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            browser.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            browser.view.topAnchor.constraint(equalTo: view.topAnchor),
            browser.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        browser.didMove(toParent: self)
    }

    func showBrowser(_ isShown: Bool) {
        browser?.view.isHidden = !isShown
        if isShown {
            video.player = nil
            stopTicking()
            scrub = nil
        }
    }

    /// `keepsFrame`: hidden behind the tabs while the iPhone still casts, so it comes back with a picture.
    func showMirror(_ isShown: Bool, keepsFrame: Bool = false) {
        loadViewIfNeeded()
        mirror.isHidden = !isShown
        if !isShown, !keepsFrame {
            mirror.image = nil
        }
        view.bringSubviewToFront(mirror)
    }

    func showMirrorFrame(_ frame: UIImage) {
        guard !mirror.isHidden else { return }
        mirror.image = frame
    }

    /// Fit shows the whole iPhone; Fill crops it to the car's screen, as CarTV's Fit button does.
    func toggleMirrorFill() {
        mirror.contentMode = mirror.contentMode == .scaleAspectFit ? .scaleAspectFill : .scaleAspectFit
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        video.backgroundColor = .black
        video.isHidden = true
        addChild(card)
        card.view.backgroundColor = .clear
        let layers: [UIView] = [card.view, video]
        for layer in layers {
            layer.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(layer)
            NSLayoutConstraint.activate([
                layer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                layer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                layer.topAnchor.constraint(equalTo: view.topAnchor),
                layer.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        }
        card.didMove(toParent: self)
        addProgress()
        addMirror()
    }

    /// The iPhone's picture fitted inside the car's screen, black around it.
    private func addMirror() {
        mirror.backgroundColor = .black
        mirror.contentMode = .scaleAspectFit
        mirror.clipsToBounds = true
        mirror.isHidden = true
        mirror.accessibilityIdentifier = "car.mirror"
        mirror.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mirror)
        NSLayoutConstraint.activate([
            mirror.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mirror.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mirror.topAnchor.constraint(equalTo: view.topAnchor),
            mirror.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func addProgress() {
        addChild(progress)
        progress.sizingOptions = .intrinsicContentSize
        progress.view.backgroundColor = .clear
        progress.view.isHidden = true
        progress.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(progress.view)
        let trailing = progress.view.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor)
        progressTrailing = trailing
        NSLayoutConstraint.activate([
            progress.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progress.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            trailing
        ])
        progress.didMove(toParent: self)
    }

    /// The window's guide around CarPlay's map buttons, so the bar never runs under them.
    func avoidMapButtons(_ guide: UILayoutGuide) {
        loadViewIfNeeded()
        progressTrailing?.isActive = false
        let trailing = progress.view.trailingAnchor.constraint(equalTo: guide.trailingAnchor)
        trailing.isActive = true
        progressTrailing = trailing
    }

    func show(_ state: CarWindowState, playback: PlaybackController) {
        loadViewIfNeeded()
        self.playback = playback
        let showsVideo = state == .video
        video.player = showsVideo ? playback.player : nil
        video.playerLayer.videoGravity = playback.videoGravity
        video.isHidden = !showsVideo
        progress.view.isHidden = !showsVideo
        if showsVideo {
            startTicking()
        } else {
            stopTicking()
            scrub = nil
        }
        updateProgress()
        card.view.isHidden = showsVideo
        // The title only for what the car is playing; on the tabs or the Pro line, Roadivo's tagline.
        let title = state == .driving || state == .needsLocation ? playback.current?.title : nil
        let content = CarWindowCard.Content(state: state, title: title)
        if card.rootView.content != content {
            card.rootView = CarWindowCard(content: content)
        }
        startClock()
    }

    /// The car's screen went away: nothing more to refresh.
    func stopUpdating() {
        stopTicking()
        clock?.invalidate()
        clock = nil
        scrub = nil
    }

    /// The road changes with the hour; nothing else redraws an idle window, so it's checked each minute.
    private func startClock() {
        guard clock == nil else { return }
        let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateMoment() }
        }
        RunLoop.main.add(timer, forMode: .common)
        clock = timer
    }

    private func updateMoment() {
        var content = card.rootView.content
        content.moment = SplashMoment(date: .now)
        if content != card.rootView.content {
            card.rootView = CarWindowCard(content: content)
        }
    }

    private func startTicking() {
        guard ticker == nil else { return }
        // Stopped when the video hides or the car disconnects (`stopUpdating`).
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateProgress() }
        }
        RunLoop.main.add(timer, forMode: .common) // Keeps ticking while CarPlay tracks a touch.
        ticker = timer
    }

    private func stopTicking() {
        ticker?.invalidate()
        ticker = nil
    }

    #if DEBUG
        private var diagnosticTicks = 0

        /// Temporary, while car playback won't start: the player's real state every 2 s in the CarPlay trace.
        private func traceDiagnostics(_ playback: PlaybackController) {
            diagnosticTicks += 1
            guard diagnosticTicks % 4 == 1 else { return }
            let player = playback.player
            let item = player.currentItem
            CarPlayTrace.write("""
            diag app \(UIApplication.shared.applicationState.rawValue), status \(playback.status), \
            time \(String(format: "%.1f", player.currentTime().seconds)), elapsed \(Int(playback.elapsed)), \
            control \(player.timeControlStatus.rawValue), waiting \(player.reasonForWaitingToPlay?.rawValue ?? "-"), \
            rate \(player.rate), item \(item?.status.rawValue ?? -1), error \(item?.error?.localizedDescription ?? "-"), \
            layer \(video.playerLayer.player != nil), ready \(video.playerLayer.isReadyForDisplay), \
            external \(player.isExternalPlaybackActive), url \(playback.current?.streamURL.lastPathComponent ?? "-")
            """)
        }
    #endif

    private func updateProgress() {
        guard let playback else { return }
        #if DEBUG
            if !video.isHidden {
                traceDiagnostics(playback)
            }
        #endif
        let bar = CarWindowProgress(
            elapsed: scrub?.target ?? playback.elapsed,
            duration: playback.duration,
            isLive: playback.isLive && playback.status == .playing
        )
        if progress.rootView != bar {
            progress.rootView = bar
        }
    }

    // MARK: Moving the video's place

    /// Only over a video with a length: live streams can't move.
    func scrubBegan(playback: PlaybackController) {
        guard !video.isHidden, let duration = playback.duration else {
            CarPlayTrace.write("drag began, no video with a length showing")
            return
        }
        scrub = CarScrub(start: playback.elapsed, duration: duration)
        CarPlayTrace.write("drag began at \(Int(playback.elapsed)) s of \(Int(duration)) s")
        updateProgress()
    }

    /// `distance`: how far the finger has moved since the drag began.
    func scrubMoved(by distance: CGFloat) {
        scrub?.drag(by: distance, across: view.bounds.width)
        updateProgress()
    }

    /// The video jumps to where the bar shows once the finger lifts.
    func scrubEnded(playback: PlaybackController) {
        guard let scrub else { return }
        self.scrub = nil
        playback.seek(to: scrub.target)
        CarPlayTrace.write("drag ended: seek to \(Int(scrub.target)) s")
        updateProgress()
    }
}

/// The progress bar along the bottom of the video, from plain values the controller pushes (LIVE for a live stream).
struct CarWindowProgress: View, Equatable {
    var elapsed: Double = 0
    var duration: Double?
    var isLive = false

    var body: some View {
        if duration != nil || isLive {
            bar
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.xl)
                .padding(.bottom, Spacing.md)
                .background {
                    LinearGradient(
                        colors: [.clear, Color.roadAsphalt.opacity(0.85)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                }
                .environment(\.colorScheme, .dark)
        }
    }

    @ViewBuilder private var bar: some View {
        if let duration {
            PlaybackProgressBar(elapsed: elapsed, duration: duration)
        } else {
            LiveBadge()
        }
    }
}

/// The road at the hour's light, as on the splash, still, with what's playing and one line underneath; its text
/// always dark-styled, like the car's screen.
struct CarWindowCard: View {
    struct Content: Equatable {
        var state: CarWindowState = .home
        var title: String?
        /// Sunrise, midday, sunset or night, by the hour (owner, 2026-10-23).
        var moment = SplashMoment(date: .now)

        /// The line under the title; nil while the video shows.
        var message: String? {
            switch state {
            case .upgrade:
                String(appLocalized: "Watching in the car is part of Roadivo Pro. Unlock it on your iPhone.")
            case .home:
                String(appLocalized: "Choose what to watch from Home, Favorites or Browser, or cast your iPhone.")
            case .driving:
                String(appLocalized: "Video is off while driving. Sound keeps playing.")
            case .needsLocation:
                String(appLocalized: "Allow Location for Roadivo on your iPhone, so video can play when you're parked.")
            case .video:
                nil
            }
        }

        var heading: String {
            title ?? String(appLocalized: Brand.tagline)
        }
    }

    let content: Content

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoadScene(time: content.moment.time, animated: false, sunIsPlayButton: true)
                .ignoresSafeArea()
            LinearGradient(colors: [.clear, Color.roadAsphalt.opacity(0.85)], startPoint: .center, endPoint: .bottom)
                .ignoresSafeArea()
            if let message = content.message {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(content.heading)
                        .font(Typography.screenTitle)
                        .lineLimit(2)
                    Text(message)
                        .font(Typography.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
                .foregroundStyle(.primary)
                .accessibilityElement(children: .combine)
                .padding(Spacing.lg)
            }
        }
        .environment(\.colorScheme, .dark)
    }
}

#Preview("Home") {
    CarWindowCard(content: CarWindowCard.Content())
        .frame(width: 800, height: 480)
}

#Preview("Driving") {
    CarWindowCard(content: CarWindowCard.Content(state: .driving, title: "Apple Sample 1"))
        .frame(width: 800, height: 480)
}

#Preview("Midday") {
    CarWindowCard(content: CarWindowCard.Content(moment: .midday))
        .frame(width: 800, height: 480)
}
