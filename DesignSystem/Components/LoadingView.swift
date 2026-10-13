import SwiftUI

struct LoadingView: View {
    var message: LocalizedStringKey = "Loading…"

    var body: some View {
        VStack(spacing: Spacing.sm) {
            ProgressView().controlSize(.large)
            Text(message).font(Typography.secondary).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}
