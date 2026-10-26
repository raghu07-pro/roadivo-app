#if DEBUG
    import SwiftUI

    /// The car screen's home, as CarTV's: Home, Favorites, Library, Cast and Browser centred along the top, and the
    /// chosen list under them, all tapped directly (DECISIONS 162).
    struct CarScreenTabsView: View {
        let model: CarScreenModel

        var body: some View {
            VStack(spacing: Spacing.sm) {
                HStack(spacing: Spacing.xs) {
                    ForEach(CarScreenModel.Tab.allCases, id: \.self) { tab in
                        Button {
                            model.actions?.select(tab)
                        } label: {
                            Text(app: tab.title)
                                .font(.headline)
                                .padding(.horizontal, Spacing.md)
                                .frame(minHeight: 48)
                                .foregroundStyle(model.tab == tab ? Color.roadOnBrand : .primary)
                                .background(model.tab == tab ? Color.roadBrand : .clear, in: Capsule())
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(model.tab == tab ? .isSelected : [])
                    }
                }
                .padding(Spacing.xxs)
                .background(.thinMaterial, in: Capsule())
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(Spacing.sm)
            .background(.regularMaterial)
        }

        @ViewBuilder private var content: some View {
            switch model.tab {
            case .home:
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
            case .browser:
                CarScreenSitesView(model: model)
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
