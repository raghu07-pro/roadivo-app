import SwiftUI

/// The player: the video with Roadivo's own controls on it, and the rest of the group below as a
/// grid. Landscape (by turning the iPhone or the full-screen button) is the video alone.
struct PlayerView: View {
    @State var viewModel: PlayerViewModel
    let onMinimize: () -> Void
    let onClose: () -> Void
    let onFavoriteChanged: () -> Void

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var controlsShown = true
    @State private var hideTask: Task<Void, Never>?
    private let orientation = OrientationLock.shared

    private var isLandscape: Bool {
        verticalSizeClass == .compact
    }

    var body: some View {
        // A ZStack, not a Group: a Group's onDisappear fired on every rotation and cleared the rotation lock.
        ZStack {
            if isLandscape {
                stage
                    .background(Color.black.ignoresSafeArea())
            } else {
                VStack(spacing: 0) {
                    stage
                        .aspectRatio(16 / 9, contentMode: .fit)
                        .background(Color.black.ignoresSafeArea(edges: .top))
                    if viewModel.showsGroups {
                        CategoryChips(
                            chips: viewModel.groups.map { .init(id: $0, title: $0) },
                            selection: $viewModel.group,
                            identifier: "player.group"
                        )
                        .padding(.top, Spacing.xs)
                    }
                    grid
                }
                .background(.roadCanvas)
            }
        }
        .overlay(alignment: isLandscape ? .center : .bottom) { upNext }
        .statusBarHidden(isLandscape)
        .persistentSystemOverlays(isLandscape ? .hidden : .automatic)
        .onAppear(perform: showControls)
        .task { viewModel.loadSource() }
        .onDisappear {
            hideTask?.cancel()
            orientation.reset()
        }
        // Paused, loading or failed keeps the controls up; once playing they hide after a moment.
        .onChange(of: viewModel.playback.status) { _, status in
            if status == .playing {
                if controlsShown {
                    scheduleHide()
                }
            } else {
                showControls()
            }
        }
    }

    /// The video, its loading and error states, and the controls on top.
    private var stage: some View {
        ZStack {
            // The video fills the screen edge to edge; the controls stay clear of the notch and corners.
            ZStack {
                Color.black
                SystemVideoPlayer(
                    player: viewModel.playback.player,
                    showsControls: false,
                    gravity: viewModel.playback.videoGravity
                )
                // Catches taps over the video to show or hide the controls.
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(perform: toggleControls)
                    .accessibilityLabel(Text("Video"))
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier("player.video")
            }
            .ignoresSafeArea(edges: isLandscape ? .all : [])
            if let screen = viewModel.playback.externalScreen {
                // The video is on the car's (or TV's) screen; say so instead of a black frame.
                VStack(spacing: Spacing.sm) {
                    Image(systemName: "airplayvideo").font(.largeTitle)
                    Text("Playing on \(screen)")
                        .font(Typography.secondary.weight(.semibold))
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(.white.opacity(0.85))
                .padding(Spacing.md)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("player.external")
            }
            if let message = viewModel.errorMessage {
                errorOverlay(message)
            } else if viewModel.playback.status == .loading {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
            }
            if controlsShown {
                PlayerControls(
                    playback: viewModel.playback,
                    title: viewModel.current?.title ?? "",
                    isFavorite: viewModel.current?.isFavorite ?? false,
                    isLandscape: isLandscape,
                    isRotationLocked: orientation.isLocked,
                    onMinimize: onMinimize,
                    onFavorite: toggleFavorite,
                    onClose: onClose,
                    onRotationLock: { orientation.toggleLock(isLandscape: isLandscape) },
                    onFullScreen: { orientation.rotate(to: isLandscape ? .portrait : .landscape) },
                    onInteraction: showControls
                )
                .transition(.opacity)
            }
        }
    }

    /// Once a video ends: over the picture full screen; upright, along the bottom over the grid, clear of
    /// the player's buttons and with room for large text (the 16:9 video is too short for it).
    private var upNext: some View {
        ZStack {
            if let upNext = viewModel.playback.upNext {
                UpNextCountdownView(
                    upNext: upNext,
                    onPlayNow: viewModel.playback.playUpNextNow,
                    onCancel: viewModel.playback.cancelUpNext
                )
                .padding(Spacing.sm)
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(
            reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.4),
            value: viewModel.playback.upNext == nil
        )
    }

    private func errorOverlay(_ message: String) -> some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill").font(.title)
            Text(message).font(Typography.secondary).multilineTextAlignment(.center)
            Button("Try Again", action: viewModel.retry)
                .buttonStyle(.borderedProminent)
                .tint(.roadBrand)
                .foregroundStyle(.roadOnBrand)
        }
        .foregroundStyle(.white)
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.75))
    }

    private var grid: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVGrid(
                    // Three posters across, or two 16:9 cards.
                    columns: [GridItem(
                        .adaptive(minimum: viewModel.gridItems.allSatisfy { $0.artwork == .poster } ? 100 : 150),
                        spacing: Spacing.sm,
                        alignment: .top
                    )],
                    spacing: Spacing.md
                ) {
                    let isWide = viewModel.gridItems.mixesArtworkShapes
                    ForEach(viewModel.gridItems) { item in
                        UpNextCard(item: item, isCurrent: item.id == viewModel.current?.id, isWide: isWide) {
                            viewModel.select(item)
                        }
                    }
                }
                .padding(Spacing.md)
                .id(viewModel.group)
            }
            .onChange(of: viewModel.group) { proxy.scrollTo(viewModel.group, anchor: .top) }
        }
    }

    // MARK: Controls

    private func toggleFavorite() {
        if viewModel.toggleFavorite() {
            onFavoriteChanged()
        }
    }

    private func toggleControls() {
        if controlsShown {
            hideTask?.cancel()
            setControls(shown: false)
        } else {
            showControls()
        }
    }

    /// Shows the controls, then hides them after 3 s of playback (never while VoiceOver is on).
    private func showControls() {
        setControls(shown: true)
        scheduleHide()
    }

    private func scheduleHide() {
        hideTask?.cancel()
        guard !voiceOver else { return }
        hideTask = Task {
            try? await Task.sleep(for: viewModel.playback.controlsHideDelay) // Cancelled by the next touch.
            guard !Task.isCancelled, viewModel.playback.status == .playing else { return }
            setControls(shown: false)
        }
    }

    private func setControls(shown: Bool) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { controlsShown = shown }
    }
}
