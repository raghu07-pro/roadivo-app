#if DEBUG
    import SwiftUI

    /// The controls over the iPhone's screen from Cast, as in CarTV: Home steps back to the tabs, End mirroring stops
    /// the broadcast, and Fit fills the screen. Over the picture they hide after a moment; a tap brings them back.
    struct CarScreenMirrorView: View {
        let model: CarScreenModel
        @State private var showsControls = true
        @State private var touches = 0
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        private var showsPicture: Bool {
            model.state == .video
        }

        var body: some View {
            ZStack {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { reveal(!showsControls) }
                if showsControls || !showsPicture {
                    controls
                        .transition(.opacity)
                }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: showsControls)
            .task(id: touches) {
                guard showsControls, showsPicture else { return }
                try? await Task.sleep(for: .seconds(4)) // Cancelled when the controls change first.
                if !Task.isCancelled {
                    showsControls = false
                }
            }
        }

        @ViewBuilder private var controls: some View {
            // Without Pro there's nowhere to go back to.
            if model.state != .upgrade {
                VStack {
                    HStack {
                        Button {
                            model.actions?.hideMirror()
                        } label: {
                            Image(systemName: "house")
                                .font(.title2)
                                .frame(width: 64, height: 56)
                        }
                        .buttonStyle(CarControlStyle())
                        .accessibilityLabel(Text(app: "Home"))
                        Spacer()
                        Button {
                            model.actions?.endMirroring()
                        } label: {
                            Text(app: "End mirroring")
                                .font(.headline)
                                .padding(.horizontal, Spacing.lg)
                                .frame(minHeight: 56)
                        }
                        .buttonStyle(CarControlStyle())
                    }
                    Spacer()
                    if showsPicture {
                        HStack {
                            Spacer()
                            Button {
                                model.actions?.toggleMirrorFill()
                                reveal(true)
                            } label: {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.title2)
                                    .frame(width: 64, height: 64)
                            }
                            .buttonStyle(CarControlStyle(shape: .circle))
                            .accessibilityLabel(Text(app: "Fit"))
                        }
                    }
                }
                .padding(Spacing.md)
            }
        }

        private func reveal(_ shows: Bool) {
            showsControls = shows
            touches += 1
        }
    }
#endif
