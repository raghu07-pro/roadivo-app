import SwiftUI

/// "What is a source?": what Roadivo can play from, and how to find the one a provider gave you. No web
/// search for playlists (DECISIONS 117). `Help` is injected by the app, as on Add a Source.
struct WhatIsASourceView<Help: View>: View {
    @ViewBuilder let help: () -> Help

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    heading(
                        "A source is where your channels come from",
                        detail: """
                        Roadivo is just a player and comes with no channels. A source tells it where to find yours:
                        """
                    )
                    kind("list.bullet.rectangle", "An M3U / M3U8 playlist link, also called an IPTV subscription link")
                    kind("server.rack", "A Jellyfin, Emby or Plex media server you have an account on")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle(padding: Spacing.lg)

                VStack(alignment: .leading, spacing: Spacing.md) {
                    heading(
                        "Where do I get one?",
                        detail: "Your IPTV provider or TV service gives you one when you sign up. To find it:"
                    )
                    kind(
                        "envelope.fill",
                        "Look in their welcome email or your account page for a link marked M3U, M3U8 or playlist"
                    )
                    kind("play.tv.fill", "Got Xtream login details instead? Choose Xtream on Add a Source and sign in")
                    kind(
                        "qrcode.viewfinder",
                        "Link shown as a QR code on a TV or computer? Scan it with the scan button on Add a Source"
                    )
                    kind(
                        "questionmark.bubble.fill",
                        "Not sure which to use? Ask your provider for your M3U or playlist link"
                    )
                    NavigationLink {
                        help()
                    } label: {
                        Label("Get Help", systemImage: "bubble.left.and.text.bubble.right.fill")
                            .font(Typography.button)
                            .foregroundStyle(.roadAccent)
                            .padding(.horizontal, Spacing.lg)
                            .frame(minHeight: 50)
                            .overlay { Capsule().strokeBorder(.roadBrandGradient, lineWidth: 2) }
                            .contentShape(Capsule())
                    }
                    .buttonStyle(PressableStyle())
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("whatIsSource.help")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle(padding: Spacing.lg)

                Text("""
                Roadivo does not provide, host, or endorse any content. Add only sources you own or have the legal \
                right to access.
                """)
                .font(Typography.caption)
                .foregroundStyle(.roadMuted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            }
            .padding(Spacing.md)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .background(.roadCanvas)
        .navigationTitle("What is a source?")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func heading(_ title: LocalizedStringKey, detail: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .font(Typography.sign)
                .foregroundStyle(.primary)
                .accessibilityAddTraits(.isHeader)
            Text(detail)
                .font(Typography.body)
                .foregroundStyle(.roadMuted)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func kind(_ symbol: String, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(.roadAccent)
                .frame(width: 28)
                .accessibilityHidden(true)
            Text(text)
                .font(Typography.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview("Light") {
    NavigationStack { WhatIsASourceView { Text("Help & FAQ") } }
}

#Preview("Dark, largest text") {
    NavigationStack { WhatIsASourceView { Text("Help & FAQ") } }
        .preferredColorScheme(.dark)
        .environment(\.dynamicTypeSize, .accessibility3)
}
