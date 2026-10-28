#if DEBUG
    import SwiftUI

    /// The controls over what the car is playing, laid out as CarTV's player (DECISIONS 162, 164): split view, back,
    /// the title and the heart along the top; play or pause in the middle; the progress bar, Channels and the screen
    /// layout along the bottom. Over the video they hide after a moment and a tap brings them back.
    struct CarScreenPlayerView: View {
        let model: CarScreenModel
        @State private var showsControls = true
        /// Each tap restarts the wait before the controls hide.
        @State private var touches = 0
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        private var isVideo: Bool {
            model.state == .video
        }

        /// Opening, or said to be playing while still at its start (DECISIONS 168): a spinner instead of a frozen
        /// frame.
        private var isLoading: Bool {
            guard let playback = model.playback, playback.isActive else { return false }
            return playback.status == .loading
                || (playback.status == .playing && !playback.isLive && playback.elapsed < 0.05)
        }

        var body: some View {
            GeometryReader { proxy in
                let panelWidth = proxy.size.width * CarScreenModel.channelsWidth
                // In the split view the Cast panel (the controller's) takes the left; everything here moves aside.
                let splitWidth = model.isPlayerSplit ? proxy.size.width * CarScreenModel.splitWidth : 0
                ZStack(alignment: .leading) {
                    ZStack {
                        // Over the video, nothing; without it, PlayCarTV's canvas, with why above play.
                        Group {
                            if isVideo {
                                Color.clear
                            } else {
                                Color.roadCanvas.ignoresSafeArea(edges: [.top, .bottom, .trailing])
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { reveal(!showsControls) }
                        if showsControls || !isVideo {
                            controls
                                .transition(.opacity)
                        } else if isLoading {
                            // With the controls hidden the spinner shows by itself; with them, in the play button.
                            spinner
                                .padding(Spacing.lg)
                                .background(.black.opacity(0.5), in: Circle())
                                .allowsHitTesting(false)
                        }
                    }
                    .padding(.leading, splitWidth)
                    if model.showsChannels {
                        CarScreenChannelsPanel(model: model)
                            .frame(width: panelWidth)
                            .frame(maxHeight: .infinity)
                            .transition(.move(edge: .leading))
                    }
                }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: showsControls)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: model.showsChannels)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: model.isPlayerSplit)
            .task(id: touches) {
                guard showsControls, isVideo else { return }
                try? await Task.sleep(for: .seconds(4)) // Cancelled when the controls change first.
                if !Task.isCancelled {
                    showsControls = false
                }
            }
        }

        private var controls: some View {
            VStack(spacing: Spacing.md) {
                HStack(spacing: Spacing.sm) {
                    circle(
                        model.isPlayerSplit ? "rectangle.split.2x1.fill" : "rectangle.split.2x1",
                        label: "Split view"
                    ) {
                        model.actions?.setPlayerSplit(!model.isPlayerSplit)
                    }
                    circle("chevron.backward", label: "Back") { model.actions?.stopPlayback() }
                    Text(model.playingTitle ?? "")
                        .font(Typography.screenTitle)
                        .foregroundStyle(isVideo ? Color.white : .primary)
                        .shadow(color: .black.opacity(isVideo ? 0.5 : 0), radius: 3)
                        .lineLimit(1)
                        .padding(.leading, Spacing.xs)
                    Spacer(minLength: 0)
                    circle(
                        model.isPlayingFavorite ? "heart.fill" : "heart",
                        label: model.isPlayingFavorite ? "Remove from Favorites" : "Add to Favorites",
                        tint: model.isPlayingFavorite ? .roadLive : .white
                    ) {
                        model.actions?.toggleFavorite()
                    }
                }
                Spacer(minLength: 0)
                if !isVideo {
                    CarScreenNotice(model: model)
                        .padding(.horizontal, Spacing.xl)
                }
                Button {
                    model.actions?.playback { $0.togglePlayPause() }
                    reveal(true)
                } label: {
                    Group {
                        if isLoading {
                            spinner
                        } else {
                            Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                                .font(.largeTitle)
                        }
                    }
                    .frame(width: 96, height: 96)
                }
                .buttonStyle(CarControlStyle(shape: .circle))
                .accessibilityLabel(Text(app: model.isPlaying ? "Pause" : "Play"))
                .accessibilityValue(isLoading ? String(appLocalized: "Loading…") : "")
                Spacer(minLength: 0)
                if let playback = model.playback {
                    CarScreenProgressBar(playback: playback, onVideo: isVideo) { reveal(true) }
                }
                HStack {
                    Button {
                        model.showsChannels = true
                        reveal(true)
                    } label: {
                        Label {
                            Text(app: "Channels")
                        } icon: {
                            Image(systemName: "list.bullet")
                        }
                        .font(Typography.sign)
                        .padding(.horizontal, Spacing.lg)
                        .frame(minHeight: 56)
                    }
                    .buttonStyle(CarControlStyle())
                    Spacer()
                    Button {
                        model.actions?.cycleAspect()
                        reveal(true)
                    } label: {
                        Label {
                            Text(app: model.aspect.title)
                        } icon: {
                            Image(systemName: "rectangle.inset.filled")
                        }
                        .font(Typography.sign)
                        .padding(.horizontal, Spacing.lg)
                        .frame(minHeight: 56)
                    }
                    .buttonStyle(CarControlStyle())
                }
            }
            .padding(Spacing.md)
            .background {
                // Shade at the top and bottom so the title and times read over any picture.
                if isVideo {
                    VStack(spacing: 0) {
                        LinearGradient(colors: [.black.opacity(0.55), .clear], startPoint: .top, endPoint: .bottom)
                            .frame(height: 160)
                        Spacer(minLength: 0)
                        LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                            .frame(height: 240)
                    }
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                }
            }
        }

        private var spinner: some View {
            ProgressView()
                .controlSize(.large)
                .tint(.white)
                .accessibilityHidden(true)
        }

        private func reveal(_ shows: Bool) {
            showsControls = shows
            touches += 1
        }

        private func circle(
            _ symbol: String,
            label: LocalizedStringResource,
            tint: Color = .white,
            action: @escaping () -> Void
        ) -> some View {
            Button {
                action()
                reveal(true)
            } label: {
                Image(systemName: symbol)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 64, height: 64)
            }
            .buttonStyle(CarControlStyle(shape: .circle))
            .accessibilityLabel(Text(app: label))
        }
    }
#endif
