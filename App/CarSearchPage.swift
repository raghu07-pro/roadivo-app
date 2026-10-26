#if DEBUG
    import SwiftUI

    /// The full-screen search page, as CarTV's: the typed text in a big field, suggestions under it, the keyboard
    /// below, and Submit search, which shows the results (DECISIONS 162).
    struct CarSearchPage: View {
        @Bindable var model: CarScreenModel
        let search: CarScreenModel.CarSearch

        var body: some View {
            VStack(spacing: Spacing.sm) {
                HStack(spacing: Spacing.sm) {
                    Button {
                        model.actions?.closePage()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .frame(width: 64, height: 56)
                    }
                    .buttonStyle(CarKeyStyle())
                    .accessibilityLabel(Text(app: "Cancel"))
                    field
                    Button {
                        model.actions?.submitSearch()
                    } label: {
                        Text(app: search.isSearch ? "Submit search" : "Done")
                            .font(.headline)
                            .padding(.horizontal, Spacing.md)
                            .frame(minHeight: 56)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.roadBrand)
                }
                let suggestions = model.suggestions
                if !suggestions.isEmpty {
                    ScrollView(.horizontal) {
                        HStack(spacing: Spacing.xs) {
                            ForEach(suggestions) { suggestion($0) }
                        }
                    }
                    .scrollIndicators(.hidden)
                    .frame(height: 52)
                }
                CarKeyboard(text: $model.searchText)
            }
            .padding(Spacing.sm)
            .background(Color.roadCanvas.ignoresSafeArea())
        }

        private var field: some View {
            HStack(spacing: Spacing.xs) {
                Image(systemName: search.isField ? "character.cursor.ibeam" : "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                if model.searchText.isEmpty {
                    Text(search.title)
                        .foregroundStyle(.secondary)
                } else {
                    Text(model.searchText)
                        .truncationMode(.head)
                }
                Spacer(minLength: 0)
            }
            .font(.title2)
            .lineLimit(1)
            .padding(.horizontal, Spacing.md)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(Color.roadSurfaceElevated, in: RoundedRectangle(cornerRadius: Radius.md))
            .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(Color.roadBrand, lineWidth: 2))
            .accessibilityElement(children: .combine)
        }

        private func suggestion(_ suggestion: CarScreenModel.Suggestion) -> some View {
            Button {
                model.actions?.open(suggestion.url)
            } label: {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: suggestion.symbol)
                        .accessibilityHidden(true)
                    Text(suggestion.title)
                        .lineLimit(1)
                }
                .font(.headline)
                .padding(.horizontal, Spacing.md)
                .frame(maxHeight: .infinity)
            }
            .buttonStyle(CarKeyStyle())
            .accessibilityHint(Text(suggestion.detail))
        }
    }
#endif
