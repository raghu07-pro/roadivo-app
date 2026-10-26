#if DEBUG
    import SwiftUI

    /// The top of a full-screen car page: its title, and a round button that closes it.
    struct CarPageHeader: View {
        let title: LocalizedStringResource
        let onClose: () -> Void

        var body: some View {
            HStack(spacing: Spacing.sm) {
                Text(app: title)
                    .font(.title2.bold())
                    .lineLimit(1)
                Spacer(minLength: 0)
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.title3.weight(.semibold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(CarBarButtonStyle())
                .accessibilityLabel(Text(app: "Close"))
            }
        }
    }
#endif
