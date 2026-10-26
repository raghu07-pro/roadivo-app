#if DEBUG
    import SwiftUI

    /// The full-screen search page, laid out like CarPlay's own search (DECISIONS 162–163): a glass search field with
    /// the typed text, a round close button, suggestions as rows, and the keyboard in a glass panel along the bottom,
    /// whose search key shows the results.
    struct CarSearchPage: View {
        @Bindable var model: CarScreenModel
        let search: CarScreenModel.CarSearch
        @State private var showsCursor = true
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            VStack(spacing: Spacing.sm) {
                HStack(spacing: Spacing.sm) {
                    field
                    Button {
                        model.actions?.closePage()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 52, height: 52)
                            .carGlass(in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(app: "Cancel"))
                }
                suggestions
                CarKeyboard(
                    text: $model.searchText,
                    isSearch: search.isSearch,
                    startsWithNumbers: search.startsWithNumbers
                ) {
                    model.actions?.submitSearch()
                }
                .padding(Spacing.sm)
                .carGlass(in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            }
            .padding(Spacing.sm)
            // Always the whole screen, with the keyboard along the bottom, whatever the suggestions.
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background { CarScreenWallpaper() }
        }

        private var field: some View {
            HStack(spacing: Spacing.sm) {
                Image(systemName: search.isField ? "character.cursor.ibeam" : "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                HStack(spacing: 2) {
                    if model.searchText.isEmpty {
                        cursor
                        Text(search.title)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(shownText)
                            .truncationMode(.head)
                        cursor
                    }
                }
                .lineLimit(1)
                Spacer(minLength: 0)
                if !model.searchText.isEmpty {
                    Button {
                        model.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(app: "Delete"))
                }
            }
            .font(.title3)
            .padding(.leading, Spacing.md)
            .padding(.trailing, Spacing.xxs)
            .frame(maxWidth: .infinity, minHeight: 52)
            .carGlass()
        }

        /// A password shows as dots, on a screen everyone in the car can see.
        private var shownText: String {
            search.isSecure ? String(repeating: "•", count: model.searchText.count) : model.searchText
        }

        /// Where the next letter goes; it blinks unless Reduce Motion is on.
        private var cursor: some View {
            Capsule()
                .fill(.blue)
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

        @ViewBuilder private var suggestions: some View {
            let rows = model.suggestions
            if rows.isEmpty {
                Spacer(minLength: 0)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(rows) { row in
                            suggestion(row)
                            if row.id != rows.last?.id {
                                Divider()
                                    .padding(.leading, 64)
                            }
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }

        private func suggestion(_ suggestion: CarScreenModel.Suggestion) -> some View {
            Button {
                model.actions?.open(suggestion.url)
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: suggestion.symbol)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Color(.systemGray), in: Circle())
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(suggestion.title)
                            .font(.title3.weight(.semibold))
                        Text(suggestion.detail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, Spacing.sm)
                .frame(minHeight: 60)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
#endif
