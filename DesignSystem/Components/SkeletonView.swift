import SwiftUI

/// A neutral placeholder for artwork that is still loading: the elevated surface with a soft
/// highlight sweeping across. It holds still under Reduce Motion.
struct SkeletonView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { context in
            let cycle = 1.4
            let phase = reduceMotion ? 0.5 : context.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: cycle) / cycle
            GeometryReader { proxy in
                let width = proxy.size.width
                ZStack(alignment: .leading) {
                    Color.roadSurfaceElevated
                    LinearGradient(
                        colors: [.white.opacity(0), .white.opacity(0.28), .white.opacity(0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: width * 0.6)
                    .offset(x: (phase * 1.6 - 0.6) * width)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview("Light") {
    SkeletonView()
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .padding()
        .background(.roadCanvas)
}

#Preview("Dark, largest text") {
    SkeletonView()
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .padding()
        .background(.roadCanvas)
        .preferredColorScheme(.dark)
        .environment(\.dynamicTypeSize, .accessibility3)
}
