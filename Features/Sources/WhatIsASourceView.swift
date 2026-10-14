import SwiftUI

/// "What is a source?": what Roadivo can play from, and where people usually get a source.
struct WhatIsASourceView: View {
    @Environment(\.openURL) private var openURL

    private static var search: URL? {
        var components = URLComponents(string: "https://www.google.com/search")
        components?.queryItems = [URLQueryItem(name: "q", value: "IPTV channels from all over the world playlist")]
        return components?.url
    }

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
                    kind("doc.text", "A config file that bundles several playlist links")
                    kind("server.rack", "A Jellyfin or Emby media server you have an account on")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle(padding: Spacing.lg)

                VStack(alignment: .leading, spacing: Spacing.md) {
                    heading(
                        "Where do I get one?",
                        detail: """
                        Your IPTV or streaming provider usually gives you the link — check their website, email, or \
                        app. Many TV stations and communities also publish public playlists.
                        """
                    )
                    Button {
                        if let url = Self.search {
                            openURL(url)
                        }
                    } label: {
                        Label("Search on Google", systemImage: "magnifyingglass")
                            .font(Typography.button)
                            .foregroundStyle(.roadAccent)
                            .padding(.horizontal, Spacing.lg)
                            .frame(minHeight: 50)
                            .overlay { Capsule().strokeBorder(.roadBrandGradient, lineWidth: 2) }
                            .contentShape(Capsule())
                    }
                    .buttonStyle(PressableStyle())
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("whatIsSource.search")
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
    NavigationStack { WhatIsASourceView() }
}

#Preview("Dark, largest text") {
    NavigationStack { WhatIsASourceView() }
        .preferredColorScheme(.dark)
        .environment(\.dynamicTypeSize, .accessibility3)
}
