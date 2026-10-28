#if DEBUG
    import SwiftUI

    /// The full-screen search page, laid out like CarTV's in PlayCarTV's theme (DECISIONS 162–163). First the field,
    /// recent library searches or results, and a choice of Voice Input or Phone Input, with Keyboard below; on
    /// Keyboard,
    /// the field sits just above PlayCarTV's keyboard with the phone and microphone beside it. The accent button
    /// searches.
    struct CarSearchPage: View {
        @Bindable var model: CarScreenModel
        let search: CarScreenModel.CarSearch
        @State private var showsCursor = true
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            Group {
                if model.searchInput == .keyboard {
                    VStack(spacing: Spacing.sm) {
                        results
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        fieldRow(showsInputs: true)
                        CarKeyboard(text: $model.searchText, startsWithNumbers: search.startsWithNumbers)
                            .frame(height: CarKeyboard.height)
                    }
                } else {
                    VStack(spacing: Spacing.sm) {
                        fieldRow(showsInputs: false)
                        if search.isLibrary, model.searchText.isEmpty {
                            recent
                        }
                        results
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        choices
                    }
                }
            }
            .padding(Spacing.sm)
            // Always the whole screen.
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.roadCanvas.ignoresSafeArea())
            .task(id: model.searchText) {
                if search.isPlace {
                    await findPlaces()
                }
            }
        }

        // MARK: - The field

        private func fieldRow(showsInputs: Bool) -> some View {
            HStack(spacing: Spacing.sm) {
                Button {
                    model.actions?.closePage()
                } label: {
                    Text(app: "Cancel")
                        .font(Typography.button)
                        .foregroundStyle(.roadAccent)
                        .padding(.horizontal, Spacing.md)
                        .frame(minHeight: 52)
                }
                .buttonStyle(CarKeyStyle())
                field
                if showsInputs {
                    square("iphone", label: "Phone Input") { model.actions?.startPhoneInput() }
                    square("mic.fill", label: "Voice Input") { model.actions?.startVoice() }
                }
                Button {
                    model.actions?.submitSearch()
                } label: {
                    Group {
                        if search.isSearch {
                            Image(systemName: "magnifyingglass")
                                .font(.title2.weight(.semibold))
                                .accessibilityLabel(Text(app: "Submit search"))
                        } else {
                            Text(app: "Done")
                                .font(Typography.button)
                        }
                    }
                    .foregroundStyle(.roadOnBrand)
                    .padding(.horizontal, Spacing.md)
                    .frame(minWidth: 88, minHeight: 52)
                    .background(
                        .roadBrandGradient,
                        in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    )
                    .opacity(model.searchText.isEmpty ? 0.45 : 1)
                }
                .buttonStyle(.plain)
            }
        }

        /// Always the field being typed in, so it's outlined in the theme's gradient, as Add Source's while editing.
        private var field: some View {
            let shape = RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
            return HStack(spacing: 2) {
                if model.searchText.isEmpty {
                    cursor
                    Text(search.title)
                        .foregroundStyle(.roadMuted)
                } else {
                    Text(shownText)
                        .truncationMode(.head)
                    cursor
                }
                Spacer(minLength: 0)
                if !model.searchText.isEmpty {
                    Button {
                        model.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.roadMuted)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(app: "Delete"))
                }
            }
            .font(.title3)
            .lineLimit(1)
            .padding(.leading, Spacing.md)
            .padding(.trailing, Spacing.xxs)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(.roadSurface, in: shape)
            .overlay { shape.strokeBorder(.roadBrandGradient, lineWidth: 2) }
        }

        /// A password shows as dots, on a screen everyone in the car can see.
        private var shownText: String {
            search.isSecure ? String(repeating: "•", count: model.searchText.count) : model.searchText
        }

        /// Where the next letter goes; it blinks unless Reduce Motion is on.
        private var cursor: some View {
            Capsule()
                .fill(.roadAccent)
                .frame(width: 2.5, height: 26)
                .opacity(showsCursor ? 1 : 0)
                .accessibilityHidden(true)
                .task {
                    guard !reduceMotion else { return }
                    while !Task.isCancelled {
                        try? await Task.sleep(for: .milliseconds(530)) // Cancelled when the page closes.
                        showsCursor.toggle()
                    }
                }
        }

        private func square(
            _ symbol: String,
            label: LocalizedStringResource,
            action: @escaping () -> Void
        ) -> some View {
            Button(action: action) {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(.roadAccent)
                    .frame(width: 64, height: 52)
            }
            .buttonStyle(CarKeyStyle())
            .accessibilityLabel(Text(app: label))
        }

        // MARK: - Recent searches and results

        /// Recent library searches, as CarTV's: a tap searches again, the bin forgets them.
        @ViewBuilder private var recent: some View {
            if !model.recentSearches.isEmpty {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "clock")
                        .font(.title2)
                        .foregroundStyle(.roadMuted)
                        .accessibilityHidden(true)
                    ScrollView(.horizontal) {
                        HStack(spacing: Spacing.xs) {
                            ForEach(model.recentSearches, id: \.self) { search in
                                Button {
                                    model.actions?.searchAgain(search)
                                } label: {
                                    Text(search)
                                        .font(Typography.sign)
                                        .padding(.horizontal, Spacing.md)
                                        .frame(minHeight: 44)
                                }
                                .buttonStyle(CarKeyStyle())
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                    Button {
                        model.actions?.clearRecentSearches()
                    } label: {
                        Image(systemName: "trash")
                            .font(.title3)
                            .foregroundStyle(.roadAccent)
                            .frame(width: 52, height: 52)
                    }
                    .buttonStyle(CarKeyStyle())
                    .accessibilityLabel(Text(app: "Delete"))
                }
            }
        }

        /// Channels and titles from the library, places for Maps, or sites and searches for the browser.
        @ViewBuilder private var results: some View {
            if search.isPlace {
                PlaceResults(search: model.placeSearch) { place in
                    model.actions?.choosePlace(place)
                } onRetry: {
                    Task { await findPlaces() }
                }
            } else if search.isLibrary, !model.libraryResults.isEmpty {
                let items = model.libraryResults
                ScrollView {
                    LazyVStack(spacing: Spacing.xs) {
                        ForEach(items) { media in
                            CarScreenMediaRow(media: media, model: model) {
                                model.actions?.play(media, queue: items)
                            }
                        }
                    }
                }
            } else if !model.suggestions.isEmpty {
                ScrollView {
                    LazyVStack(spacing: Spacing.xs) {
                        ForEach(model.suggestions) { suggestion in
                            Button {
                                model.actions?.open(suggestion.url)
                            } label: {
                                Label {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(suggestion.title)
                                            .font(Typography.sign)
                                        Text(suggestion.detail)
                                            .font(Typography.secondary)
                                            .foregroundStyle(.roadMuted)
                                    }
                                    .lineLimit(1)
                                } icon: {
                                    Image(systemName: suggestion.symbol)
                                        .foregroundStyle(.roadAccent)
                                }
                                .padding(.horizontal, Spacing.md)
                                .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                            }
                            .buttonStyle(CarKeyStyle())
                        }
                    }
                }
            }
        }

        /// Run for each change of what's typed, as the iPhone's Maps search runs; a newer change cancels it.
        private func findPlaces() async {
            await model.directions?.lookUp(model.searchText) { model.placeSearch = $0 }
        }

        // MARK: - Voice, the iPhone, or the keyboard

        private var choices: some View {
            VStack(spacing: Spacing.md) {
                HStack(spacing: Spacing.xxl) {
                    option(
                        "mic.fill",
                        title: model.voice?.isListening == true ? "Stop listening" : "Voice Input",
                        isOn: true
                    ) {
                        model.searchInput == .voice ? model.actions?.stopVoice() : model.actions?.startVoice()
                    }
                    option("iphone", title: "Phone Input", isOn: model.searchInput == .phone) {
                        model.actions?.startPhoneInput()
                    }
                }
                if let note {
                    Text(app: note)
                        .font(Typography.body)
                        .foregroundStyle(.roadMuted)
                        .multilineTextAlignment(.center)
                }
                Button {
                    model.actions?.chooseKeyboard()
                } label: {
                    Label {
                        Text(app: "Keyboard")
                    } icon: {
                        Image(systemName: "keyboard")
                            .foregroundStyle(.roadAccent)
                    }
                    .font(Typography.button)
                    .padding(.horizontal, Spacing.lg)
                    .frame(minHeight: 52)
                }
                .buttonStyle(CarKeyStyle())
            }
        }

        /// What's happening: listening, why the microphone can't, or where to type.
        private var note: LocalizedStringResource? {
            switch model.voice?.state {
            case .listening: return "Listening…"
            case .denied:
                return "Turn on Microphone and Speech Recognition for PlayCarTV in Settings to search by voice."
            case .failed: return "Voice search isn't available right now."
            default: return model.searchInput == .phone ? "Open PlayCarTV on your iPhone to type." : nil
            }
        }

        /// A big round choice, as CarTV's in the theme's colours: the gradient when it's the way in use, a pale
        /// wash otherwise, as `IconTile`'s two styles.
        private func option(
            _ symbol: String,
            title: LocalizedStringResource,
            isOn: Bool,
            action: @escaping () -> Void
        ) -> some View {
            Button(action: action) {
                VStack(spacing: Spacing.sm) {
                    Image(systemName: symbol)
                        .font(.largeTitle.weight(.semibold))
                        .foregroundStyle(isOn ? AnyShapeStyle(.roadOnBrand) : AnyShapeStyle(.roadAccent))
                        .frame(width: 104, height: 104)
                        .background {
                            if isOn {
                                Circle().fill(.roadBrandGradient)
                            } else {
                                Circle().fill(Color.roadBrand.opacity(0.14))
                            }
                        }
                    Text(app: title)
                        .font(Typography.sign)
                        .foregroundStyle(.primary)
                }
            }
            .buttonStyle(.plain)
        }
    }
#endif
