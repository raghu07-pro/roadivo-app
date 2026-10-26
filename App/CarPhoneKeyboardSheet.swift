#if DEBUG
    import SwiftUI

    /// Phone Input on the iPhone, as CarTV's "CarPlay Keyboard" sheet in Roadivo's theme: the iPhone's own keyboard,
    /// its text on the car's screen as it's typed, and its return key searching there (DECISIONS 163).
    struct CarPhoneKeyboardSheet: View {
        @Bindable var input: CarPhoneInput
        let request: CarPhoneInput.Request
        @FocusState private var isFocused: Bool

        var body: some View {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        HStack(spacing: Spacing.md) {
                            IconTile(systemImage: "car.fill", size: 46)
                            Text(app: "Synced with your car")
                                .font(Typography.secondary)
                                .foregroundStyle(.roadMuted)
                        }
                        fieldCard
                        PrimaryButton(
                            text: Text(app: request.isSearch ? "Search" : "Done"),
                            systemImage: request.isSearch ? "magnifyingglass" : "checkmark"
                        ) {
                            input.submit()
                        }
                        .accessibilityIdentifier("carKeyboard.submit")
                    }
                    .padding(Spacing.md)
                    .frame(maxWidth: 600)
                    .frame(maxWidth: .infinity)
                }
                .background(.roadCanvas)
                .navigationTitle(Text(app: "Car Keyboard"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button { input.end() } label: {
                            Label { Text(app: "Close") } icon: { Image(systemName: "xmark") }
                        }
                        .accessibilityIdentifier("carKeyboard.close")
                    }
                }
            }
            .onAppear { isFocused = true }
        }

        /// The field on a card, outlined in the theme's gradient while typing, as Add Source's.
        private var fieldCard: some View {
            let shape = RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
            return field
                .font(Typography.body)
                .focused($isFocused)
                .submitLabel(request.isSearch ? .search : .done)
                .onSubmit { input.submit() }
                .padding(Spacing.md)
                .frame(minHeight: 56)
                .background(.roadSurface, in: shape)
                .overlay {
                    shape.strokeBorder(
                        isFocused ? AnyShapeStyle(.roadBrandGradient) : AnyShapeStyle(Color.primary.opacity(0.06)),
                        lineWidth: isFocused ? 2 : 1
                    )
                }
                .accessibilityIdentifier("carKeyboard.field")
        }

        @ViewBuilder private var field: some View {
            if request.isSecure {
                SecureField(text: $input.text) { Text(request.title) }
            } else {
                TextField(text: $input.text) { Text(request.title) }
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
        }
    }

    extension View {
        /// The car's Phone Input sheet, whenever the car's screen asks for it.
        func carPhoneKeyboard() -> some View {
            // Read while the view draws, so the car's request opens the sheet at once.
            let request = CarPhoneInput.shared.request
            return sheet(isPresented: Binding(
                get: { request != nil },
                set: {
                    if !$0 {
                        CarPhoneInput.shared.end()
                    }
                }
            )) {
                if let request {
                    CarPhoneKeyboardSheet(input: CarPhoneInput.shared, request: request)
                        .presentationDetents([.large])
                        .presentationBackground(.roadCanvas)
                }
            }
        }
    }
#endif
