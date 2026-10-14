import StoreKit
import SwiftUI

/// Settings: Pro, Media, Preferences, Legal, About — the reference's sections.
struct SettingsView<SourcesScreen: View>: View {
    let isPro: Bool
    let onUpgrade: () -> Void
    @ViewBuilder let sourcesScreen: () -> SourcesScreen

    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview
    @State private var language = LanguageViewModel()
    @State private var theme = ThemeViewModel()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    proBanner
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                Section {
                    NavigationLink {
                        sourcesScreen()
                    } label: {
                        row(
                            symbol: "antenna.radiowaves.left.and.right",
                            title: "Manage Sources",
                            detail: "M3U · Jellyfin · Emby · Plex · Xtream"
                        )
                    }
                    .accessibilityIdentifier("settings.sources")
                } header: {
                    Text("Media").foregroundStyle(.roadMuted)
                }

                Section {
                    NavigationLink {
                        ThemeView(viewModel: theme)
                    } label: {
                        LabeledContent {
                            Text(theme.summary).foregroundStyle(.roadMuted)
                        } label: {
                            row(symbol: "paintpalette.fill", title: "Theme", detail: nil)
                        }
                    }
                    .accessibilityIdentifier("settings.theme")
                    NavigationLink {
                        LanguageView(viewModel: language)
                    } label: {
                        LabeledContent {
                            Text(language.currentName).foregroundStyle(.roadMuted)
                        } label: {
                            row(symbol: "globe", title: "Language", detail: nil)
                        }
                    }
                    .accessibilityIdentifier("settings.language")
                } header: {
                    Text("Preferences").foregroundStyle(.roadMuted)
                }

                Section {
                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        row(symbol: "hand.raised.fill", title: "Privacy Policy", detail: nil)
                    }
                    .accessibilityIdentifier("settings.privacy")
                    if let url = LegalLinks.terms {
                        Button { openURL(url) } label: {
                            row(symbol: "doc.text.fill", title: "Terms of Use (EULA)", detail: nil)
                        }
                    }
                } header: {
                    Text("Legal").foregroundStyle(.roadMuted)
                }

                Section {
                    Button(action: rate) {
                        row(symbol: "star.fill", title: "Rate Roadivo", detail: nil)
                    }
                    .accessibilityIdentifier("settings.rate")
                    shareRow
                    NavigationLink {
                        HelpView()
                    } label: {
                        row(symbol: "questionmark", title: "Help & FAQ", detail: nil)
                    }
                    .accessibilityIdentifier("settings.help")
                    LabeledContent {
                        Text(AppInfo.version).foregroundStyle(.roadMuted)
                    } label: {
                        row(symbol: "info", title: "Version", detail: nil)
                    }
                } header: {
                    Text("About").foregroundStyle(.roadMuted)
                } footer: {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(app: Brand.tagline).fontWeight(.semibold)
                        Text("Roadivo is a player only. It doesn't provide, host or recommend any content.")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(.roadCanvas)
            .navigationTitle("Settings")
        }
    }

    // MARK: Pro

    /// The theme's gradient as a banner: an upsell for free users, a quiet
    /// thank-you once Pro is active.
    @ViewBuilder private var proBanner: some View {
        if isPro {
            bannerContent(
                symbol: "checkmark.seal.fill",
                subtitle: "Active. Thanks for supporting Roadivo.",
                showsChevron: false
            )
            .accessibilityElement(children: .combine)
        } else {
            Button(action: onUpgrade) {
                bannerContent(symbol: "crown.fill", subtitle: "Unlock all features", showsChevron: true)
            }
            .buttonStyle(PressableStyle())
            .accessibilityIdentifier("settings.pro")
        }
    }

    private func bannerContent(symbol: String, subtitle: LocalizedStringKey, showsChevron: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
        return HStack(spacing: Spacing.sm) {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .frame(width: 44, height: 44)
                .background(Color.roadOnBrand.opacity(0.18), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Roadivo Pro").font(Typography.button)
                Text(subtitle).font(Typography.caption)
            }
            .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .opacity(0.85)
                    .accessibilityHidden(true)
            }
        }
        .foregroundStyle(.roadOnBrand)
        .padding(Spacing.md)
        .background {
            ZStack(alignment: .trailing) {
                // Deep end behind the text, so even the small subtitle reads
                // at 4.5:1 or more in every accent.
                shape.fill(LinearGradient(
                    colors: [.roadBrandDeep, .roadBrand],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                // A large, faint crown in the corner, cropped by the banner.
                Image(systemName: "crown.fill")
                    .font(.system(size: 96, weight: .bold))
                    .foregroundStyle(Color.roadOnBrand.opacity(0.1))
                    .rotationEffect(.degrees(-14))
                    .offset(x: 18, y: 14)
                    .accessibilityHidden(true)
            }
            .clipShape(shape)
        }
        .contentShape(shape)
    }

    // MARK: Rate and share

    private var appStore: AppStoreLinks {
        AppStoreLinks.current
    }

    /// The App Store's "Write a Review" page. Before the listing exists (no
    /// `APP_STORE_ID`), the system review prompt instead.
    private func rate() {
        if let url = appStore.writeReview {
            openURL(url)
        } else {
            requestReview()
        }
    }

    @ViewBuilder private var shareRow: some View {
        let message = Text(app: Brand.shareMessage)
        let label = row(symbol: "square.and.arrow.up", title: "Share Roadivo", detail: nil)
        Group {
            if let page = appStore.page {
                ShareLink(item: page, subject: Text("Roadivo"), message: message) { label }
            } else {
                ShareLink(item: String(appLocalized: Brand.shareMessage), subject: Text("Roadivo")) { label }
            }
        }
        .accessibilityIdentifier("settings.share")
    }

    // MARK: Rows

    private func row(symbol: String, title: LocalizedStringKey, detail: LocalizedStringKey?) -> some View {
        HStack(spacing: Spacing.sm) {
            IconTile(systemImage: symbol)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).foregroundStyle(Color.primary)
                if let detail {
                    Text(detail).font(Typography.caption).foregroundStyle(.roadMuted)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview("Free") {
    SettingsView(isPro: false, onUpgrade: {}, sourcesScreen: { EmptyView() })
}

#Preview("Pro, dark") {
    SettingsView(isPro: true, onUpgrade: {}, sourcesScreen: { EmptyView() })
        .preferredColorScheme(.dark)
}

#Preview("Largest text") {
    SettingsView(isPro: false, onUpgrade: {}, sourcesScreen: { EmptyView() })
        .environment(\.dynamicTypeSize, .accessibility3)
}
