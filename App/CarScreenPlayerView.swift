#if DEBUG
    import SwiftUI

    /// The controls over what the car is playing, tapped directly: previous, next and Close along the top, and back
    /// 15 seconds, play or pause, and forward 15 in the middle. Over the video they hide after a moment and a tap
    /// brings them back; a drag across moves the video's place (DECISIONS 162).
    struct CarScreenPlayerView: View {
        let model: CarScreenModel
        @State private var showsControls = true
        /// Each tap restarts the wait before the controls hide.
        @State private var touches = 0
        @State private var scrubbing = false
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        private var isVideo: Bool {
            model.state == .video
        }

        var body: some View {
            ZStack {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { reveal(!showsControls) }
                    .gesture(scrub, isEnabled: isVideo && !model.isLive)
                if showsControls || !isVideo {
                    controls
                        .transition(.opacity)
                }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: showsControls)
            .task(id: touches) {
                guard showsControls, isVideo else { return }
                try? await Task.sleep(for: .seconds(4)) // Cancelled when the controls change first.
                if !Task.isCancelled {
                    showsControls = false
                }
            }
        }

        private var controls: some View {
            VStack {
                HStack(spacing: Spacing.sm) {
                    round("backward.end.fill", label: "Previous channel") { $0.previous() }
                    round("forward.end.fill", label: "Next channel") { $0.next() }
                    Spacer()
                    Button {
                        model.actions?.stopPlayback()
                    } label: {
                        Text(app: "Close")
                            .font(.headline)
                            .padding(.horizontal, Spacing.lg)
                            .frame(minHeight: 56)
                    }
                    .buttonStyle(CarControlStyle())
                }
                Spacer()
                HStack(spacing: Spacing.xl) {
                    if !model.isLive {
                        round("gobackward.15", label: "Back 15 seconds") { $0.skip(by: -15) }
                    }
                    round(
                        model.isPlaying ? "pause.fill" : "play.fill",
                        label: model.isPlaying ? "Pause" : "Play",
                        size: 88
                    ) { $0.togglePlayPause() }
                    if !model.isLive {
                        round("goforward.15", label: "Forward 15 seconds") { $0.skip(by: 15) }
                    }
                }
                Spacer()
            }
            .padding(Spacing.md)
        }

        private var scrub: some Gesture {
            DragGesture(minimumDistance: 24)
                .onChanged { drag in
                    if !scrubbing {
                        scrubbing = true
                        model.actions?.scrubBegan()
                    }
                    model.actions?.scrubMoved(by: drag.translation.width)
                }
                .onEnded { _ in
                    scrubbing = false
                    model.actions?.scrubEnded()
                }
        }

        private func reveal(_ shows: Bool) {
            showsControls = shows
            touches += 1
        }

        private func round(
            _ symbol: String,
            label: LocalizedStringResource,
            size: CGFloat = 64,
            action: @escaping (PlaybackController) -> Void
        ) -> some View {
            Button {
                model.actions?.playback(action)
                reveal(true)
            } label: {
                Image(systemName: symbol)
                    .font(size > 64 ? .largeTitle : .title2)
                    .frame(width: size, height: size)
            }
            .buttonStyle(CarControlStyle(shape: .circle))
            .accessibilityLabel(Text(app: label))
        }
    }
#endif
