import SwiftUI

/// A thick bar with the time played and the length, readable from a dashboard: Car Mode's and the CarPlay window's
/// (DECISIONS 114, 154). It takes plain values, so the CarPlay window can push them itself.
struct PlaybackProgressBar: View {
    let elapsed: Double
    let duration: Double

    @ScaledMetric(relativeTo: .title2) private var barHeight: CGFloat = 8

    var body: some View {
        let elapsed = min(max(elapsed, 0), duration)
        VStack(spacing: Spacing.xs) {
            Capsule()
                .fill(.white.opacity(0.18))
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        Capsule()
                            .fill(.roadBrandGradient)
                            .frame(width: max(barHeight, proxy.size.width * elapsed / max(duration, 1)))
                    }
                }
                .frame(height: barHeight)
            HStack {
                Text(PlaybackClock.text(elapsed))
                Spacer(minLength: Spacing.sm)
                Text(PlaybackClock.text(duration))
            }
            .font(Typography.readout)
            .foregroundStyle(.white.opacity(0.85))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Playback position"))
        .accessibilityValue(Text("\(PlaybackClock.text(elapsed)) of \(PlaybackClock.text(duration))"))
        .accessibilityIdentifier("carMode.progress")
    }
}

#Preview("Part-watched") {
    PlaybackProgressBar(elapsed: 754, duration: 2900)
        .padding()
        .background(Color.black)
        .environment(\.colorScheme, .dark)
}
