import SwiftUI

/// "New Version Available": a centred card over the dimmed app, with Update Now and a close button
/// beneath it. It scrolls when large text makes it taller than the screen.
struct UpdatePromptView: View {
    let release: AppRelease
    let onUpdate: () -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .accessibilityHidden(true)
            ViewThatFits(in: .vertical) {
                content
                ScrollView { content.padding(.vertical, Spacing.lg) }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }

    private var content: some View {
        VStack(spacing: Spacing.lg) {
            VStack(spacing: Spacing.md) {
                Image(systemName: "arrow.down")
                    .font(.title.weight(.bold))
                    .foregroundStyle(.roadOnBrand)
                    .frame(width: 64, height: 64)
                    .background(.roadBrandGradient, in: Circle())
                    .accessibilityHidden(true)
                Text("New Version Available")
                    .font(Typography.screenTitle)
                    .accessibilityAddTraits(.isHeader)
                Text("PlayCarTV \(release.version) is now available.")
                    .font(Typography.sign)
                if !release.notes.isEmpty {
                    Text(release.notes)
                        .font(Typography.body)
                        .foregroundStyle(.roadMuted)
                        .lineLimit(10)
                }
                PrimaryButton(title: "Update Now", systemImage: "arrow.down.circle.fill", action: onUpdate)
                    .accessibilityIdentifier("update.now")
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(Spacing.lg)
            .frame(maxWidth: 420)
            .background(.roadSurface, in: RoundedRectangle(cornerRadius: Radius.lg * 1.5, style: .continuous))
            .padding(.horizontal, Spacing.lg)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(.white.opacity(0.25), in: Circle())
            }
            .accessibilityLabel(Text("Close"))
            .accessibilityIdentifier("update.close")
        }
    }
}

#Preview("Light") {
    UpdatePromptView(
        release: AppRelease(
            version: "1.1.0",
            notes: "Smoother live streams and faster loading.\n\nNew: search by voice.",
            storeURL: URL(filePath: "/")
        ),
        onUpdate: {},
        onClose: {}
    )
}

#Preview("Dark, largest text") {
    UpdatePromptView(
        release: AppRelease(version: "1.1.0", notes: "Smoother live streams.", storeURL: URL(filePath: "/")),
        onUpdate: {},
        onClose: {}
    )
    .preferredColorScheme(.dark)
    .environment(\.dynamicTypeSize, .accessibility3)
}
