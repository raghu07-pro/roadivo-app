import SwiftUI

struct OnboardingView: View {
    @State var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $viewModel.currentIndex) {
                ForEach(viewModel.pages) { page in
                    OnboardingPageView(page: page).tag(page.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea(edges: .top)
            // Dark status-bar text would vanish into the dusk and night skies.
            .statusBarHidden()

            VStack(spacing: Spacing.md) {
                PrimaryButton(
                    title: viewModel.isLastPage ? "Get Started" : "Continue",
                    systemImage: viewModel.isLastPage ? "play.fill" : "chevron.right.2"
                ) {
                    withAnimation { viewModel.advance() }
                }
                .accessibilityValue(Text("Page \(viewModel.currentIndex + 1) of \(viewModel.pages.count)"))
                .accessibilityIdentifier("onboarding.continue")

                PageDots(count: viewModel.pages.count, current: viewModel.currentIndex)

                Text("PlayCarTV is a player only. It doesn't include or sell any channels or content.")
                    .font(Typography.caption)
                    .foregroundStyle(.roadMuted)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.sm)
            .frame(maxWidth: 520)
        }
        .overlay(alignment: .topTrailing) {
            if !viewModel.isLastPage {
                Button("Skip") { viewModel.skip() }
                    .font(Typography.button)
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.md)
                    .frame(minHeight: 44)
                    .background(.black.opacity(0.35), in: Capsule())
                    .padding(Spacing.md)
                    .accessibilityIdentifier("onboarding.skip")
            }
        }
        .background(.roadCanvas)
        .accessibilityElement(children: .contain)
    }
}

/// Page dots as short lane dashes; the current one is long, in the theme's gradient.
private struct PageDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == current ? AnyShapeStyle(.roadBrandGradient) : AnyShapeStyle(.quaternary))
                    .frame(width: index == current ? 28 : 10, height: 6)
            }
        }
        .animation(.snappy, value: current)
        // Decorative: the position is announced on the Continue button.
        .accessibilityHidden(true)
    }
}

#Preview("Light") {
    OnboardingView(viewModel: OnboardingViewModel {})
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    OnboardingView(viewModel: OnboardingViewModel {})
        .preferredColorScheme(.dark)
}

#Preview("Largest text") {
    OnboardingView(viewModel: OnboardingViewModel {})
        .environment(\.dynamicTypeSize, .accessibility3)
}
