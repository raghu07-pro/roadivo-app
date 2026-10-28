#if DEBUG
    import SwiftUI

    /// The library search's results, laid out like CarTV's in PlayCarTV's theme (DECISIONS 163): back, the search with
    /// its microphone, and reload along the top; then each source's matches in a row, or one source's in a grid.
    struct CarSearchResultsPage: View {
        let model: CarScreenModel
        /// One source's matches alone, from its section's title; nil for every source.
        let source: UUID?

        var body: some View {
            let sections = model.resultSections
            VStack(alignment: .leading, spacing: Spacing.md) {
                header
                if sections.isEmpty {
                    Text(app: "No results found")
                        .font(.title2)
                        .foregroundStyle(.roadMuted)
                        .padding(.leading, Spacing.xs)
                } else if let section = sections.first(where: { $0.id == source }) {
                    title(of: section, opens: false)
                    ScrollView {
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: CarScreenMediaTile.side), spacing: Spacing.md)],
                            alignment: .leading,
                            spacing: Spacing.lg
                        ) {
                            tiles(section)
                        }
                    }
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: Spacing.lg) {
                            ForEach(sections) { section in
                                VStack(alignment: .leading, spacing: Spacing.sm) {
                                    title(of: section, opens: true)
                                    ScrollView(.horizontal) {
                                        LazyHStack(alignment: .top, spacing: Spacing.md) {
                                            tiles(section)
                                        }
                                    }
                                    .scrollIndicators(.hidden)
                                }
                            }
                        }
                    }
                }
            }
            .padding(Spacing.sm)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.roadCanvas.ignoresSafeArea())
        }

        // MARK: - Back, the search, reload

        private var header: some View {
            HStack(spacing: Spacing.sm) {
                round("chevron.left", label: "Back") {
                    source == nil ? model.actions?.editSearch(speaking: false) : model.actions?.showResults(from: nil)
                }
                HStack(spacing: Spacing.xs) {
                    Button {
                        model.actions?.editSearch(speaking: true)
                    } label: {
                        Image(systemName: "mic.fill")
                            .font(.title2)
                            .foregroundStyle(.roadAccent)
                            .frame(width: 52, height: 52)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(app: "Voice Input"))
                    Button {
                        model.actions?.editSearch(speaking: false)
                    } label: {
                        Text(model.searchText)
                            .font(.title2)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, Spacing.sm)
                .frame(minHeight: 64)
                .background(.roadSurfaceElevated, in: Capsule())
                round("arrow.clockwise", label: "Refresh") { model.actions?.reloadResults() }
            }
        }

        private func round(
            _ symbol: String,
            label: LocalizedStringResource,
            action: @escaping () -> Void
        ) -> some View {
            Button(action: action) {
                Image(systemName: symbol)
                    .font(.title.weight(.semibold))
                    .foregroundStyle(.roadAccent)
                    .frame(width: 64, height: 64)
            }
            .buttonStyle(CarKeyStyle(isRound: true))
            .accessibilityLabel(Text(app: label))
        }

        // MARK: - Sections

        /// A source's name and count; in the list of sources, a tap shows its matches alone.
        @ViewBuilder
        private func title(of section: CarScreenModel.ResultSection, opens: Bool) -> some View {
            let label = HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                Text(section.title)
                    .font(Typography.screenTitle)
                    .foregroundStyle(.primary)
                Text(app: "\(section.items.count) items")
                    .font(.title3)
                    .foregroundStyle(.roadMuted)
                if opens {
                    Image(systemName: "chevron.right")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.roadAccent)
                }
            }
            .lineLimit(1)
            .padding(.leading, Spacing.xs)
            if opens {
                Button {
                    model.actions?.showResults(from: section.id)
                } label: {
                    label.frame(minHeight: 44)
                }
                .buttonStyle(.plain)
            } else {
                label
            }
        }

        private func tiles(_ section: CarScreenModel.ResultSection) -> some View {
            ForEach(section.items) { media in
                CarScreenMediaTile(media: media, model: model) {
                    model.actions?.play(media, queue: section.items)
                }
            }
        }
    }
#endif
