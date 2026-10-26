#if DEBUG
    import SwiftUI

    /// The car screen's home, as CarTV's: Home, Favorites, Library, Cast and Browser centred along the top, and the
    /// chosen list under them, all tapped directly (DECISIONS 162). In Roadivo's theme (owner, 2026-10-26; DECISIONS
    /// 163): the canvas, a surface bar with the chosen tab on the theme's gradient, and the lists as cards.
    struct CarScreenTabsView: View {
        let model: CarScreenModel

        var body: some View {
            VStack(spacing: Spacing.md) {
                tabBar
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(Spacing.sm)
            .background(Color.roadCanvas.ignoresSafeArea())
        }

        private var tabBar: some View {
            HStack(spacing: Spacing.xxs) {
                ForEach(CarScreenModel.Tab.allCases, id: \.self) { tab in
                    let isChosen = model.tab == tab
                    Button {
                        model.actions?.select(tab)
                    } label: {
                        Text(app: tab.title)
                            .font(Typography.sign)
                            .foregroundStyle(isChosen ? AnyShapeStyle(.roadOnBrand) : AnyShapeStyle(.primary))
                            .padding(.horizontal, Spacing.md)
                            .frame(minHeight: 48)
                            .background {
                                if isChosen {
                                    Capsule().fill(.roadBrandGradient)
                                }
                            }
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isChosen ? .isSelected : [])
                }
            }
            .padding(Spacing.xxs)
            .background(.roadSurface, in: Capsule())
            .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
            .overlay(alignment: .trailing) {
                // The library's search beside the tabs, as CarTV's.
                Button {
                    model.actions?.showLibrarySearch()
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.roadAccent)
                        .frame(width: 56, height: 56)
                        .background(.roadSurface, in: Circle())
                        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(app: "Search channels and titles"))
                .offset(x: 56 + Spacing.sm)
            }
        }

        @ViewBuilder private var content: some View {
            switch model.tab {
            // Browser opens the browser itself (`CarScreenActions.select`), so its tab never shows a list.
            case .home, .browser:
                list(model.menu.home(limit: CarPlayMenu.itemLimit).recent, empty: "Nothing here yet")
            case .favorites:
                list(model.menu.favorites, empty: "Nothing here yet")
            case .library:
                library
            case .cast:
                message(
                    "Cast anything to this screen",
                    detail: "On your iPhone, open Roadivo and go to Discover › Cast to Screen to get started.",
                    symbol: "rectangle.on.rectangle"
                )
            }
        }

        @ViewBuilder private var library: some View {
            if let group = model.group {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Button {
                        model.group = nil
                    } label: {
                        Label {
                            Text(group)
                                .foregroundStyle(.primary)
                        } icon: {
                            Image(systemName: "chevron.backward")
                                .foregroundStyle(.roadAccent)
                        }
                        .font(Typography.sectionTitle)
                        .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(Text(app: "Back"))
                    list(model.items(in: group), empty: "Nothing here yet")
                }
            } else if model.menu.groups.isEmpty {
                message("Add a source on your iPhone", detail: nil, symbol: "antenna.radiowaves.left.and.right")
            } else {
                ScrollView {
                    LazyVStack(spacing: Spacing.sm) {
                        ForEach(model.menu.groups, id: \.title) { group in
                            Button {
                                model.group = group.title
                            } label: {
                                HStack(spacing: Spacing.md) {
                                    IconTile(systemImage: "rectangle.stack.fill", style: .soft, size: 44)
                                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                                        Text(group.title)
                                            .font(Typography.sign)
                                        Text(app: "\(group.items.count) items")
                                            .font(Typography.secondary)
                                            .foregroundStyle(.roadMuted)
                                    }
                                    .lineLimit(1)
                                    Spacer()
                                    Image(systemName: "chevron.forward")
                                        .font(.headline)
                                        .foregroundStyle(.roadAccent)
                                        .accessibilityHidden(true)
                                }
                                .padding(Spacing.md)
                                .frame(minHeight: 72)
                            }
                            .buttonStyle(CarCardStyle())
                        }
                    }
                }
            }
        }

        @ViewBuilder
        private func list(_ items: [MediaItem], empty: LocalizedStringResource) -> some View {
            if items.isEmpty {
                message(empty, detail: nil, symbol: "play.rectangle")
            } else {
                ScrollView {
                    LazyVStack(spacing: Spacing.sm) {
                        ForEach(items) { media in
                            CarScreenMediaRow(media: media, model: model) {
                                model.actions?.play(media, queue: items)
                            }
                        }
                    }
                }
            }
        }

        private func message(
            _ title: LocalizedStringResource,
            detail: LocalizedStringResource?,
            symbol: String
        ) -> some View {
            VStack(spacing: Spacing.sm) {
                IconTile(systemImage: symbol, style: .soft, size: 64)
                Text(app: title)
                    .font(Typography.sectionTitle)
                if let detail {
                    Text(app: detail)
                        .font(Typography.body)
                        .foregroundStyle(.roadMuted)
                }
            }
            .multilineTextAlignment(.center)
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
#endif
