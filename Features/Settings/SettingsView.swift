import SwiftUI

/// Settings: Pro, Media, Preferences, Legal, About — the reference's sections.
struct SettingsView<SourcesScreen: View>: View {
    let isPro: Bool
    let onUpgrade: () -> Void
    let onAddSource: () -> Void
    @ViewBuilder let sourcesScreen: () -> SourcesScreen

    @Environment(\.openURL) private var openURL
    @State private var language = LanguageViewModel()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if isPro {
                        HStack(spacing: Spacing.sm) {
                            proIcon
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Roadivo Pro").font(Typography.button)
                                Text("Active. Thanks for supporting Roadivo.")
                                    .font(Typography.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, Spacing.xxs)
                        .accessibilityElement(children: .combine)
                    } else {
                        Button(action: onUpgrade) {
                            HStack(spacing: Spacing.sm) {
                                proIcon
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Roadivo Pro").font(Typography.button).foregroundStyle(Color.primary)
                                    Text("Unlock all features").font(Typography.caption)
                                        .foregroundStyle(Color.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, Spacing.xxs)
                        }
                        .accessibilityIdentifier("settings.pro")
                    }
                }

                Section("Media") {
                    NavigationLink {
                        sourcesScreen()
                    } label: {
                        row(
                            symbol: "antenna.radiowaves.left.and.right",
                            title: "Manage Sources",
                            detail: "M3U · Jellyfin · Emby · Xtream"
                        )
                    }
                    .accessibilityIdentifier("settings.sources")
                    Button(action: onAddSource) {
                        row(symbol: "plus.circle", title: "Add a Source", detail: nil)
                    }
                    .accessibilityIdentifier("settings.addSource")
                }

                Section("Preferences") {
                    NavigationLink {
                        LanguageView(viewModel: language)
                    } label: {
                        LabeledContent {
                            Text(language.currentName)
                        } label: {
                            row(symbol: "globe", title: "Language", detail: nil)
                        }
                    }
                    .accessibilityIdentifier("settings.language")
                }

                Section("Legal") {
                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        row(symbol: "hand.raised", title: "Privacy Policy", detail: nil)
                    }
                    .accessibilityIdentifier("settings.privacy")
                    if let url = LegalLinks.terms {
                        Button { openURL(url) } label: {
                            row(symbol: "doc.text", title: "Terms of Use (EULA)", detail: nil)
                        }
                    }
                }

                Section {
                    NavigationLink {
                        HelpView()
                    } label: {
                        row(symbol: "questionmark.circle", title: "Help & FAQ", detail: nil)
                    }
                    .accessibilityIdentifier("settings.help")
                    LabeledContent("Version", value: AppInfo.version)
                } header: {
                    Text("About")
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

    private var proIcon: some View {
        Image(systemName: "crown.fill")
            .font(.title3)
            .foregroundStyle(.roadAccent)
            .frame(width: 36, height: 36)
            .background(.roadAccent.opacity(0.15), in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
            .accessibilityHidden(true)
    }

    private func row(symbol: String, title: LocalizedStringKey, detail: LocalizedStringKey?) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(.roadAccent)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).foregroundStyle(Color.primary)
                if let detail {
                    Text(detail).font(Typography.caption).foregroundStyle(Color.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview("Free") {
    SettingsView(isPro: false, onUpgrade: {}, onAddSource: {}, sourcesScreen: { EmptyView() })
}

#Preview("Pro, dark") {
    SettingsView(isPro: true, onUpgrade: {}, onAddSource: {}, sourcesScreen: { EmptyView() })
        .preferredColorScheme(.dark)
}
