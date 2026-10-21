import SwiftUI

/// A search bar with a microphone: type, or tap the mic to search by voice (tap again to stop).
/// While listening the mic becomes a pulsing brand-coloured waveform and the prompt reads "Listening…".
struct SearchField: View {
    @Binding var text: String
    let prompt: LocalizedStringKey
    var isListening = false
    var onMic: (() -> Void)?
    /// Told when the field gains or loses the keyboard, so a screen can offer its own Cancel.
    var onFocusChange: ((Bool) -> Void)?

    @FocusState private var isFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.roadMuted)
                .accessibilityHidden(true)
            TextField(text: $text, prompt: Text(isListening ? "Listening…" : prompt)) {
                Text(prompt)
            }
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.search)
            .focused($isFocused)
            .accessibilityIdentifier("search.field")
            if !text.isEmpty, !isListening {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(Text("Clear search"))
                .accessibilityIdentifier("search.clear")
            }
            if let onMic {
                micButton(onMic)
            }
        }
        .padding(.leading, Spacing.sm)
        .padding(.trailing, Spacing.xxs)
        .frame(minHeight: 48)
        .background(.roadSurface, in: Capsule())
        .overlay {
            Capsule().strokeBorder(
                isListening ? AnyShapeStyle(.roadBrandGradient) : AnyShapeStyle(Color.primary.opacity(0.08)),
                lineWidth: isListening ? 1.5 : 1
            )
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: isListening)
        .onChange(of: isFocused) { _, focused in
            onFocusChange?(focused)
        }
    }

    private func micButton(_ action: @escaping () -> Void) -> some View {
        Button {
            isFocused = false
            action()
        } label: {
            Image(systemName: isListening ? "waveform" : "mic.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(isListening ? AnyShapeStyle(.roadOnBrand) : AnyShapeStyle(.roadAccent))
                .symbolEffect(.variableColor.iterative, options: .repeating, isActive: isListening && !reduceMotion)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 40, height: 40)
                .background {
                    if isListening {
                        Circle().fill(.roadBrandGradient)
                    }
                }
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .accessibilityLabel(isListening ? Text("Stop listening") : Text("Search by voice"))
        .accessibilityIdentifier("search.mic")
    }
}

#Preview("Light") {
    VStack(spacing: Spacing.md) {
        SearchField(text: .constant(""), prompt: "Search channels and titles", onMic: {})
        SearchField(text: .constant("Football"), prompt: "Search channels and titles", isListening: true, onMic: {})
    }
    .padding()
    .background(.roadCanvas)
}

#Preview("Dark, largest text") {
    SearchField(text: .constant("Coastal"), prompt: "Search channels and titles", onMic: {})
        .padding()
        .background(.roadCanvas)
        .preferredColorScheme(.dark)
        .environment(\.dynamicTypeSize, .accessibility3)
}
