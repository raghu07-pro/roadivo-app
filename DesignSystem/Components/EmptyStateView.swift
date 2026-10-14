import SwiftUI

/// An empty screen that still looks finished: a brand-tile symbol, title, one sentence and the next
/// step. Scrolls (centred while it fits), so large text never clips.
struct EmptyStateView<Actions: View>: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let systemImage: String
    @ViewBuilder var actions: Actions

    @ScaledMetric(relativeTo: .largeTitle) private var badge: CGFloat = 76

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: Spacing.md) {
                    emblem
                        .padding(.bottom, Spacing.xs)
                    VStack(spacing: Spacing.xs) {
                        Text(title)
                            .font(Typography.sectionTitle)
                            .foregroundStyle(.primary)
                            .accessibilityAddTraits(.isHeader)
                        Text(message)
                            .font(Typography.secondary)
                            .foregroundStyle(.secondary)
                    }
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    actions
                        .padding(.top, Spacing.xs)
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.vertical, Spacing.lg)
                .frame(maxWidth: 440)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private var emblem: some View {
        let side = min(badge, 120)
        return ZStack {
            Circle()
                .fill(Color.roadBrand.opacity(0.07))
                .frame(width: side * 1.9, height: side * 1.9)
            Circle()
                .fill(Color.roadBrand.opacity(0.12))
                .frame(width: side * 1.45, height: side * 1.45)
            Image(systemName: systemImage)
                .font(.system(size: side * 0.42, weight: .semibold))
                .foregroundStyle(.roadOnBrand)
                .frame(width: side, height: side)
                .background(BrandFill(cornerRadius: side * 0.3))
        }
        .accessibilityHidden(true)
    }
}

#Preview("Light") {
    EmptyStateView(
        title: "Your library is empty",
        message: "Add an M3U playlist link or file, or import videos from your iPhone.",
        systemImage: "play.square.stack"
    ) {
        PrimaryButton(title: "Add a Source", systemImage: "plus", isCompact: true) {}
    }
    .background(.roadCanvas)
}

#Preview("Dark, largest text") {
    EmptyStateView(
        title: "Nothing saved yet",
        message: "Touch and hold any channel, or tap the heart in the player, to keep it here.",
        systemImage: "heart"
    ) {
        PrimaryButton(title: "Browse Home", systemImage: "house.fill", isCompact: true) {}
    }
    .background(.roadCanvas)
    .preferredColorScheme(.dark)
    .environment(\.dynamicTypeSize, .accessibility3)
}
