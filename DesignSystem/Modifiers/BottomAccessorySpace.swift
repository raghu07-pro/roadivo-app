import SwiftUI

extension EnvironmentValues {
    /// The height of the bar floating over the bottom of a tab (the mini player), 0 when none.
    @Entry var bottomAccessoryHeight: CGFloat = 0
}

extension View {
    /// Keeps a screen's content clear of the floating mini player. An inset set outside a
    /// NavigationStack doesn't reach its screens, so each screen reserves the space itself.
    func clearsBottomAccessory() -> some View {
        modifier(BottomAccessorySpace())
    }
}

private struct BottomAccessorySpace: ViewModifier {
    @Environment(\.bottomAccessoryHeight) private var height

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear
                .frame(height: height)
                .accessibilityHidden(true)
        }
    }
}
