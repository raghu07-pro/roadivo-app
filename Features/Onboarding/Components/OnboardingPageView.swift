import SwiftUI

/// One onboarding page: the view from the driver's seat, with the car's
/// centre screen showing the page's idea, then the words. Portrait stacks them; landscape sits them
/// side by side. Pages scroll, so large text never gets squeezed.
struct OnboardingPageView: View {
    let page: OnboardingPage

    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        if verticalSizeClass == .compact {
            HStack(spacing: 0) {
                scene
                ScrollView { words.padding(Spacing.lg) }
                    .scrollBounceBehavior(.basedOnSize)
                    .frame(maxWidth: .infinity)
            }
        } else {
            // Always scrollable: the scene takes 55% of the page and the words
            // get whatever they need at any text size.
            ScrollView {
                VStack(spacing: 0) {
                    scene.containerRelativeFrame(.vertical) { height, _ in height * 0.6 }
                    words.padding(.horizontal, Spacing.lg).padding(.vertical, Spacing.lg)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private var scene: some View {
        CockpitView(time: page.time, content: page.screen)
            .overlay(alignment: .bottom) {
                LinearGradient(colors: [.clear, Color.roadCanvas], startPoint: .top, endPoint: .bottom)
                    .frame(height: 40)
                    .accessibilityHidden(true)
            }
    }

    private var words: some View {
        VStack(spacing: Spacing.sm) {
            Text(app: page.title)
                .font(Typography.hero)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("onboarding.title.\(page.id)")
            Text(app: page.message)
                .font(Typography.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: 560)
    }
}
