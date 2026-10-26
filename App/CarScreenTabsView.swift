#if DEBUG
    import SwiftUI

    /// The car screen's home (DECISIONS 162–164, 167), all tapped directly in Roadivo's theme: its mark, the five tabs
    /// with their icons and the search along the top; Home's shelves, Favorites' and Library's grids of pictures, and
    /// Cast's three steps under them.
    struct CarScreenTabsView: View {
        let model: CarScreenModel

        var body: some View {
            VStack(spacing: Spacing.md) {
                topBar
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(Spacing.sm)
            .background {
                // The theme's glow from the top corner, so the screen has depth rather than a flat fill.
                ZStack {
                    Color.roadCanvas
                    RadialGradient(
                        colors: [Color.roadBrand.opacity(0.22), .clear],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 700
                    )
                }
                .ignoresSafeArea()
            }
        }

        // MARK: - Along the top

        /// The mark and the search hold the corners; the tabs stay centred, dropping their icons on a narrow screen.
        private var topBar: some View {
            ZStack {
                ViewThatFits(in: .horizontal) {
                    tabBar(showsIcons: true)
                    tabBar(showsIcons: false)
                }
                .padding(.horizontal, Self.corner + Spacing.sm)
                HStack {
                    CarBrandMark(side: Self.corner)
                    Spacer(minLength: 0)
                    searchButton
                }
            }
        }

        private static let corner: CGFloat = 56

        private func tabBar(showsIcons: Bool) -> some View {
            HStack(spacing: Spacing.xxs) {
                ForEach(CarScreenModel.Tab.allCases, id: \.self) { tab in
                    tabButton(tab, showsIcon: showsIcons)
                }
            }
            .padding(Spacing.xxs)
            .background(.roadSurface, in: Capsule())
            .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
            .fixedSize()
        }

        private func tabButton(_ tab: CarScreenModel.Tab, showsIcon: Bool) -> some View {
            let isChosen = model.tab == tab
            // The iPhone still casts behind the other tabs, as CarTV's red dot shows.
            let isCasting = tab == .cast && model.isCasting
            return Button {
                model.actions?.select(tab)
            } label: {
                HStack(spacing: Spacing.xs) {
                    if showsIcon {
                        Image(systemName: Self.symbol(of: tab))
                            .imageScale(.medium)
                            .accessibilityHidden(true)
                    }
                    Text(app: tab.title)
                    if isCasting {
                        Circle()
                            .fill(.roadLive)
                            .overlay { Circle().strokeBorder(.white, lineWidth: 1.5) }
                            .frame(width: 12, height: 12)
                            .accessibilityHidden(true)
                    }
                }
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
            .accessibilityValue(isCasting ? String(appLocalized: "Casting") : "")
        }

        private static func symbol(of tab: CarScreenModel.Tab) -> String {
            switch tab {
            case .home: "house.fill"
            case .favorites: "heart.fill"
            case .library: "rectangle.stack.fill"
            case .cast: "rectangle.on.rectangle"
            case .browser: "globe"
            }
        }

        /// The library's search, as CarTV's beside the tabs.
        private var searchButton: some View {
            Button {
                model.actions?.showLibrarySearch()
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.roadAccent)
                    .frame(width: Self.corner, height: Self.corner)
                    .background(.roadSurface, in: Circle())
                    .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(app: "Search channels and titles"))
        }

        // MARK: - The tabs' pages

        @ViewBuilder private var content: some View {
            switch model.tab {
            // Browser opens the browser itself (`CarScreenActions.select`), so its tab never shows a page.
            case .home, .browser:
                home
            case .favorites:
                grid(model.menu.favorites, empty: "Nothing here yet", symbol: "heart")
            case .library:
                library
            case .cast:
                cast
            }
        }

        /// Shelves, as a TV app's: what was played lately, the favourites and the library's groups, each opening its
        /// tab (no featured banner: owner, 2026-10-26).
        @ViewBuilder private var home: some View {
            let recent = model.menu.home(limit: CarPlayMenu.itemLimit).recent
            let favorites = Array(model.menu.favorites.prefix(12))
            if recent.isEmpty, favorites.isEmpty, model.menu.groups.isEmpty {
                message("Add a source on your iPhone", detail: nil, symbol: "antenna.radiowaves.left.and.right")
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        if !recent.isEmpty {
                            shelf("Recent", opens: nil) { cards(recent) }
                        }
                        if !favorites.isEmpty {
                            shelf("Favorites", opens: .favorites) { cards(favorites, queue: favorites) }
                        }
                        if !model.menu.groups.isEmpty {
                            shelf("Library", opens: .library) {
                                ForEach(model.menu.groups.prefix(12), id: \.title) { groupCard($0) }
                            }
                        }
                    }
                    .padding(.vertical, Spacing.xs)
                }
                .scrollIndicators(.hidden)
            }
        }

        private func shelf(
            _ title: LocalizedStringResource,
            opens tab: CarScreenModel.Tab?,
            @ViewBuilder items: () -> some View
        ) -> some View {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(alignment: .firstTextBaseline) {
                    Text(app: title)
                        .font(Typography.sectionTitle)
                    Spacer(minLength: Spacing.sm)
                    if let tab {
                        Button {
                            model.actions?.select(tab)
                        } label: {
                            HStack(spacing: Spacing.xxs) {
                                Text(app: "See All")
                                Image(systemName: "chevron.forward")
                                    .imageScale(.small)
                                    .accessibilityHidden(true)
                            }
                            .font(Typography.sign)
                            .foregroundStyle(.roadAccent)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Spacing.xs)
                ScrollView(.horizontal) {
                    LazyHStack(alignment: .top, spacing: Spacing.md) {
                        items()
                    }
                    .padding(.horizontal, Spacing.xs)
                }
                .scrollIndicators(.hidden)
            }
        }

        /// `queue`: what next and previous step through; the items themselves unless it's more.
        private func cards(_ items: [MediaItem], queue: [MediaItem]? = nil) -> some View {
            ForEach(items) { media in
                CarScreenMediaTile(media: media, model: model, width: CarScreenMediaTile.cardWidth, aspect: 16 / 9) {
                    model.actions?.play(media, queue: queue ?? items)
                }
            }
        }

        /// A group of the library as a cover, opening its videos on the Library tab.
        private func groupCard(_ group: CarPlayMenu.Group) -> some View {
            CarGroupCard(group: group, model: model) {
                model.tab = .library
                model.group = group.title
            }
        }

        /// Pictures in as many columns as the car's screen holds.
        @ViewBuilder
        private func grid(_ items: [MediaItem], empty: LocalizedStringResource, symbol: String) -> some View {
            if items.isEmpty {
                message(empty, detail: nil, symbol: symbol)
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: CarScreenMediaTile.cardWidth), spacing: Spacing.md)],
                        alignment: .leading,
                        spacing: Spacing.lg
                    ) {
                        cards(items)
                    }
                    .padding(Spacing.xs)
                }
                .scrollIndicators(.hidden)
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
                    grid(model.items(in: group), empty: "Nothing here yet", symbol: "play.rectangle")
                }
            } else if model.menu.groups.isEmpty {
                message("Add a source on your iPhone", detail: nil, symbol: "antenna.radiowaves.left.and.right")
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: CarScreenMediaTile.cardWidth), spacing: Spacing.md)],
                        alignment: .leading,
                        spacing: Spacing.md
                    ) {
                        ForEach(model.menu.groups, id: \.title) { groupCard($0) }
                    }
                    .padding(Spacing.xs)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    // MARK: - Cast and the empty pages

    extension CarScreenTabsView {
        /// How to cast, in the three steps it takes, rather than a sentence to remember.
        private var cast: some View {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    VStack(spacing: Spacing.sm) {
                        IconTile(systemImage: "rectangle.on.rectangle", style: .soft, size: 64)
                        Text(app: "Cast anything to this screen")
                            .font(Typography.sectionTitle)
                    }
                    HStack(alignment: .top, spacing: Spacing.md) {
                        step(1, symbol: "iphone", text: "Open Roadivo on your iPhone")
                        step(2, symbol: "sparkles.tv", text: "Go to Discover › Cast to Screen")
                        step(3, symbol: "play.fill", text: "Tap Start mirroring")
                    }
                }
                .multilineTextAlignment(.center)
                .padding(Spacing.lg)
                .frame(maxWidth: 900)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
        }

        /// A numbered step: it is an order to follow, so the numbers carry it.
        private func step(_ number: Int, symbol: String, text: LocalizedStringResource) -> some View {
            VStack(spacing: Spacing.sm) {
                ZStack(alignment: .topLeading) {
                    IconTile(systemImage: symbol, size: 56)
                    Text(String(number))
                        .font(Typography.cardTitle)
                        .foregroundStyle(.roadOnBrand)
                        .frame(width: 26, height: 26)
                        .background(.roadAccent, in: Circle())
                        .offset(x: -10, y: -10)
                        .accessibilityHidden(true)
                }
                Text(app: text)
                    .font(Typography.sign)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(Spacing.md)
            .cardStyle()
            .accessibilityElement(children: .combine)
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

    /// Roadivo's mark in the corner: the road at the hour's light with the sun as a play button, as on its icon.
    private struct CarBrandMark: View {
        let side: CGFloat

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: side * 0.24, style: .continuous)
            RoadScene(time: SplashMoment(date: .now).time, animated: false, sunIsPlayButton: true)
                .frame(width: side, height: side)
                .clipShape(shape)
                .overlay { shape.strokeBorder(Color.primary.opacity(0.08), lineWidth: 1) }
                .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
                .accessibilityHidden(true)
        }
    }
#endif
