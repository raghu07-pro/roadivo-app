#if DEBUG
    import SwiftUI

    /// Roadivo's own keyboard for the car screen, which has no system one, laid out like CarPlay's and CarTV's
    /// (DECISIONS 161, 163): letters, numbers and symbols pages, grey Shift and Delete, `/`, `.` and `.com` for
    /// addresses, and the blue search key.
    struct CarKeyboard: View {
        /// Which keys show: 123 opens the numbers, #+= the rest of the symbols, ABC the letters again.
        enum Page {
            case letters
            case numbers
            case symbols

            var rows: [String] {
                switch self {
                case .letters: ["qwertyuiop", "asdfghjkl", "zxcvbnm"]
                case .numbers: ["1234567890", "-/:;()$&@\"", ".,?!'"]
                case .symbols: ["[]{}#%^*+=", "_\\|~<>€£¥•", ".,?!'"]
                }
            }
        }

        @Binding var text: String
        /// Search for a search box, Done for another field.
        let isSearch: Bool
        let onSubmit: () -> Void
        @State private var isShifted = false
        @State private var page: Page

        /// Each key's height and the gap between keys, in points.
        static let keyHeight: CGFloat = 48
        static let gap: CGFloat = 8
        /// Four rows of keys and the gaps between them.
        static let height = keyHeight * 4 + gap * 3

        // Developer UI in a Debug-only screen: names the catalog lacks are plain English, as in the tap test.
        private static let numbersName = "123"
        private static let symbolsName = "#+="
        private static let lettersName = "ABC"
        private static let spaceName = "Space"
        private static let dotCom = ".com"

        /// `startsWithNumbers`: a number or phone field opens on the numbers.
        init(text: Binding<String>, isSearch: Bool, startsWithNumbers: Bool = false, onSubmit: @escaping () -> Void) {
            _text = text
            self.isSearch = isSearch
            self.onSubmit = onSubmit
            _page = State(initialValue: startsWithNumbers ? .numbers : .letters)
        }

        var body: some View {
            GeometryReader { proxy in
                // Ten keys fit across the top row; the other rows use the same key width, centred.
                let unit = (proxy.size.width - Self.gap * 9) / 10
                let rows = page.rows
                VStack(spacing: Self.gap) {
                    keys(rows[0], width: unit)
                    keys(rows[1], width: unit)
                    HStack(spacing: Self.gap) {
                        switch page {
                        case .letters:
                            function("shift", label: "Shift", width: unit * 1.5, isOn: isShifted) {
                                isShifted.toggle()
                            }
                            keys(rows[2], width: unit)
                        case .numbers:
                            pageKey(Self.symbolsName, to: .symbols, width: unit * 1.5)
                            keys(rows[2], width: unit * 1.4)
                        case .symbols:
                            pageKey(Self.numbersName, to: .numbers, width: unit * 1.5)
                            keys(rows[2], width: unit * 1.4)
                        }
                        function("delete.backward", label: String(appLocalized: "Delete"), width: unit * 1.5) {
                            if !text.isEmpty {
                                text.removeLast()
                            }
                        }
                    }
                    HStack(spacing: Self.gap) {
                        if page == .letters {
                            pageKey(Self.numbersName, to: .numbers, width: unit * 1.5)
                        } else {
                            pageKey(Self.lettersName, to: .letters, width: unit * 1.5)
                        }
                        typing("/", width: unit)
                        Button {
                            type(" ")
                        } label: {
                            Image(systemName: "space")
                                .font(.title3)
                                .frame(maxWidth: .infinity, minHeight: Self.keyHeight, maxHeight: Self.keyHeight)
                        }
                        .buttonStyle(CarKeyCapStyle(kind: .character))
                        .accessibilityLabel(Self.spaceName)
                        typing(".", width: unit)
                        typing(Self.dotCom, width: unit * 1.5)
                        submit(width: unit * 2)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(height: Self.height)
        }

        private func keys(_ characters: String, width: CGFloat) -> some View {
            HStack(spacing: Self.gap) {
                ForEach(Array(characters), id: \.self) { character in
                    let shown = isShifted && page == .letters ? String(character).uppercased() : String(character)
                    typing(shown, width: width)
                }
            }
        }

        /// A key that types `characters`.
        private func typing(_ characters: String, width: CGFloat) -> some View {
            Button {
                type(characters)
            } label: {
                Text(characters)
                    .font(.title2)
                    .frame(width: width, height: Self.keyHeight)
            }
            .buttonStyle(CarKeyCapStyle(kind: .character))
        }

        private func pageKey(_ name: String, to target: Page, width: CGFloat) -> some View {
            Button {
                page = target
                isShifted = false
            } label: {
                Text(name)
                    .font(.title3)
                    .frame(width: width, height: Self.keyHeight)
            }
            .buttonStyle(CarKeyCapStyle(kind: .function))
        }

        private func function(
            _ symbol: String,
            label: String,
            width: CGFloat,
            isOn: Bool = false,
            action: @escaping () -> Void
        ) -> some View {
            Button(action: action) {
                Image(systemName: isOn ? "\(symbol).fill" : symbol)
                    .font(.title3)
                    .frame(width: width, height: Self.keyHeight)
            }
            .buttonStyle(CarKeyCapStyle(kind: .function))
            .accessibilityLabel(label)
            .accessibilityAddTraits(isOn ? .isSelected : [])
        }

        private func submit(width: CGFloat) -> some View {
            Button(action: onSubmit) {
                Group {
                    if isSearch {
                        Image(systemName: "magnifyingglass")
                            .accessibilityLabel(Text(app: "Submit search"))
                    } else {
                        Text(app: "Done")
                    }
                }
                .font(.title3.weight(.semibold))
                .frame(width: width, height: Self.keyHeight)
            }
            .buttonStyle(CarKeyCapStyle(kind: .submit))
        }

        private func type(_ characters: String) {
            guard (text + characters).utf16.count <= 4096 else { return }
            text += characters
            isShifted = false
        }
    }

    #Preview {
        @Previewable @State var text = ""
        CarKeyboard(text: $text, isSearch: true) {}
            .padding()
            .frame(width: 900)
            .background(CarScreenWallpaper())
    }
#endif
