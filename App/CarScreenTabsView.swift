#if DEBUG
    import SwiftUI

    /// The car screen's home, as CarTV's: Home, Favorites, Library, Cast and Browser centred along the top, and the
    /// chosen list under them, all tapped directly (DECISIONS 162). Drawn as CarPlay drew the template tabs: a glass
    /// capsule with a grey pill under the chosen tab, on CarPlay's wallpaper (DECISIONS 163).
    struct CarScreenTabsView: View {
        let model: CarScreenModel

        var body: some View {
            VStack(spacing: Spacing.sm) {
                tabBar
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(Spacing.sm)
            .background { CarScreenWallpaper() }
        }

        private var tabBar: some View {
            HStack(spacing: Spacing.xxs) {
                ForEach(CarScreenModel.Tab.allCases, id: \.self) { tab in
                    let isChosen = model.tab == tab
                    Button {
                        model.actions?.select(tab)
                    } label: {
                        Text(app: tab.title)
                            .font(isChosen ? .body.weight(.semibold) : .body)
                            .foregroundStyle(.primary)
                            .padding(.horizontal, Spacing.sm)
                            .frame(minHeight: 44)
                            .background(isChosen ? Color.primary.opacity(0.1) : .clear, in: Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isChosen ? .isSelected : [])
                }
            }
            .padding(Spacing.xxs)
            .carGlass()
            .overlay(alignment: .trailing) {
                // The library's search beside the tabs, as CarTV's.
                Button {
                    model.actions?.showLibrarySearch()
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 52, height: 52)
                        .carGlass(in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(app: "Search channels and titles"))
                .offset(x: 52 + Spacing.sm)
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
                    detail: "On your iPhone, open Roadivo and go to Discover › Cast to Screen to get started."
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
                        } icon: {
                            Image(systemName: "chevron.backward")
                        }
                        .font(.headline)
                        .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(Text(app: "Back"))
                    list(model.items(in: group), empty: "Nothing here yet")
                }
            } else if model.menu.groups.isEmpty {
                message("Add a source on your iPhone", detail: nil)
            } else {
                ScrollView {
                    LazyVStack(spacing: Spacing.xs) {
                        ForEach(model.menu.groups, id: \.title) { group in
                            Button {
                                model.group = group.title
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(group.title)
                                            .font(.headline)
                                        Text(app: "\(group.items.count) items")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.forward")
                                        .foregroundStyle(.secondary)
                                        .accessibilityHidden(true)
                                }
                                .padding(Spacing.sm)
                                .frame(minHeight: 64)
                            }
                            .buttonStyle(CarKeyStyle())
                        }
                    }
                }
            }
        }

        @ViewBuilder
        private func list(_ items: [MediaItem], empty: LocalizedStringResource) -> some View {
            if items.isEmpty {
                message(empty, detail: nil)
            } else {
                ScrollView {
                    LazyVStack(spacing: Spacing.xs) {
                        ForEach(items) { media in
                            CarScreenMediaRow(media: media, model: model) {
                                model.actions?.play(media, queue: items)
                            }
                        }
                    }
                }
            }
        }

        private func message(_ title: LocalizedStringResource, detail: LocalizedStringResource?) -> some View {
            VStack(spacing: Spacing.xs) {
                Text(app: title)
                    .font(.title2.bold())
                if let detail {
                    Text(app: detail)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
            .multilineTextAlignment(.center)
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
#endif
