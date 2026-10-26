#if DEBUG
    import SwiftUI

    /// The car player's progress, as CarTV's: the time so far, a bar to tap or drag anywhere along, and the length.
    /// Follows the player as it plays; the video moves when the finger lifts. LIVE for a live stream.
    struct CarScreenProgressBar: View {
        let playback: PlaybackController
        /// A touch on the bar, so the controls stay up while it's used.
        let onTouch: () -> Void
        /// Where the finger is, while dragging.
        @State private var target: Double?
        /// Ends with the drag, also when it's cancelled, so the bar never sticks at a dropped drag.
        @GestureState private var isDragging = false

        private static let trackHeight: CGFloat = 8
        private static let knob: CGFloat = 24

        var body: some View {
            Group {
                if let duration = playback.duration, duration > 0 {
                    let shown = min(max(target ?? playback.elapsed, 0), duration)
                    HStack(spacing: Spacing.md) {
                        Text(PlaybackClock.text(shown))
                        track(shown: shown, duration: duration)
                        Text(PlaybackClock.text(duration))
                    }
                    .font(Typography.readout)
                    .monospacedDigit()
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("Playback position"))
                    .accessibilityValue(Text("\(PlaybackClock.text(shown)) of \(PlaybackClock.text(duration))"))
                    .accessibilityAdjustableAction { direction in
                        let step: Double = direction == .increment ? 15 : -15
                        seek(to: playback.elapsed + step)
                    }
                } else if playback.isLive {
                    LiveBadge()
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, Spacing.lg)
            .frame(minHeight: 56)
            .background(.black.opacity(0.55), in: Capsule())
            .onChange(of: isDragging) {
                if !isDragging {
                    target = nil
                }
            }
        }

        private func track(shown: Double, duration: Double) -> some View {
            GeometryReader { proxy in
                let width = proxy.size.width
                let fraction = shown / duration
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.25))
                        .frame(height: Self.trackHeight)
                    Capsule()
                        .fill(.roadBrandGradient)
                        .frame(width: max(Self.trackHeight, width * fraction), height: Self.trackHeight)
                    Circle()
                        .fill(.white)
                        .frame(width: Self.knob, height: Self.knob)
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                        .offset(x: min(max(width * fraction - Self.knob / 2, 0), width - Self.knob))
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                // From zero, so a tap jumps there too.
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .updating($isDragging) { _, dragging, _ in dragging = true }
                        .onChanged { drag in
                            target = position(of: drag.location.x, across: width, duration: duration)
                            onTouch()
                        }
                        .onEnded { drag in
                            seek(to: position(of: drag.location.x, across: width, duration: duration))
                            target = nil
                        }
                )
            }
            .frame(height: 44)
        }

        private func position(of offset: CGFloat, across width: CGFloat, duration: Double) -> Double {
            guard width > 0 else { return 0 }
            return min(max(Double(offset / width), 0), 1) * duration
        }

        private func seek(to seconds: Double) {
            playback.seek(to: seconds)
            CarPlayTrace.write("bar: seek to \(Int(seconds)) s")
        }
    }
#endif
