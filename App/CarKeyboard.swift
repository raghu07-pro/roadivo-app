#if DEBUG
    import SwiftUI

    /// Roadivo's own keyboard for the car screen, which has no system one (DECISIONS 161): big keys that fill the
    /// space they're given.
    struct CarKeyboard: View {
        @Binding var text: String
        @State private var isShifted = false

        private static let rows = ["1234567890", "qwertyuiop", "asdfghjkl-"]

        var body: some View {
            VStack(spacing: Spacing.xs) {
                ForEach(Self.rows, id: \.self) { row in
                    HStack(spacing: Spacing.xs) {
                        ForEach(Array(row), id: \.self) { key(String($0)) }
                    }
                }
                HStack(spacing: Spacing.xs) {
                    // Developer UI in a Debug-only screen: labels the catalog lacks are plain English.
                    symbolKey("shift", label: "Shift", isOn: isShifted) { isShifted.toggle() }
                    ForEach(Array("zxcvbnm."), id: \.self) { key(String($0)) }
                    symbolKey("delete.backward", label: String(appLocalized: "Delete")) {
                        if !text.isEmpty {
                            text.removeLast()
                        }
                    }
                }
                HStack(spacing: Spacing.xs) {
                    key("@")
                    key("/")
                    symbolKey("space", label: "Space") { type(" ") }
                        .layoutPriority(1)
                        .frame(minWidth: 0, maxWidth: .infinity)
                    key("'")
                    key("?")
                }
            }
        }

        private func key(_ character: String) -> some View {
            let shown = isShifted ? character.uppercased() : character
            return Button {
                type(shown)
            } label: {
                Text(shown)
                    .font(.title2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .buttonStyle(CarKeyStyle())
        }

        private func symbolKey(
            _ symbol: String,
            label: String,
            isOn: Bool = false,
            action: @escaping () -> Void
        ) -> some View {
            Button(action: action) {
                Image(systemName: isOn ? "\(symbol).fill" : symbol)
                    .font(.title2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .buttonStyle(CarKeyStyle())
            .accessibilityLabel(label)
            .accessibilityAddTraits(isOn ? .isSelected : [])
        }

        private func type(_ characters: String) {
            guard (text + characters).utf16.count <= 4096 else { return }
            text += characters
            isShifted = false
        }
    }

    #Preview {
        @Previewable @State var text = ""
        CarKeyboard(text: $text)
            .padding()
            .frame(width: 900, height: 360)
    }
#endif
