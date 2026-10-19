import SwiftUI

/// The Browser's address bar: a search box on the start page; on a page, the site's name, which shows
/// the whole address to edit once tapped.
struct AddressField: View {
    @Bindable var viewModel: BrowserViewModel
    let isOnStartPage: Bool

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.roadMuted)
                .accessibilityHidden(true)
            TextField(text: $viewModel.address, prompt: Text("Search or enter website")) {
                Text("Address")
            }
            .keyboardType(.webSearch)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.go)
            .focused($isFocused)
            .onSubmit(submit)
            .accessibilityIdentifier("browser.address")
            if isFocused, !viewModel.address.isEmpty {
                Button {
                    viewModel.address = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(Text("Clear address"))
            }
        }
        .padding(.leading, Spacing.sm)
        .padding(.trailing, Spacing.xxs)
        .frame(minHeight: 48)
        .background(.roadSurface, in: Capsule())
        .overlay {
            Capsule().strokeBorder(
                isFocused ? AnyShapeStyle(.roadBrandGradient) : AnyShapeStyle(Color.primary.opacity(0.08)),
                lineWidth: isFocused ? 1.5 : 1
            )
        }
        .onChange(of: isFocused) { _, focused in
            if !isOnStartPage {
                viewModel.isEditingAddress = focused
            }
        }
    }

    /// A padlock for a secure page, a globe for any other.
    private var symbol: String {
        if isOnStartPage || isFocused {
            return "magnifyingglass"
        }
        return viewModel.pageURL?.scheme?.lowercased() == "https" ? "lock.fill" : "globe"
    }

    /// The text is read before the keyboard goes, as leaving the field puts the site's name back.
    private func submit() {
        let text = viewModel.address
        isFocused = false
        viewModel.open(text)
    }
}
