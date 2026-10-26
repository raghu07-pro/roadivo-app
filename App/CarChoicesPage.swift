#if DEBUG
    import SwiftUI

    /// A webpage dropdown's options on the car screen, which shows no system picker (DECISIONS 161).
    struct CarChoicesPage: View {
        let model: CarScreenModel
        let title: String
        let options: [CarBrowserInputBridge.Option]

        var body: some View {
            VStack(alignment: .leading, spacing: Spacing.sm) {
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
                    Text(title)
                        .font(.title2.bold())
                        .lineLimit(1)
                }
                ScrollView {
                    LazyVStack(spacing: Spacing.xs) {
                        ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                            Button {
                                model.actions?.choose(index)
                            } label: {
                                HStack {
                                    Text(option.title)
                                    Spacer()
                                    if option.isSelected {
                                        Image(systemName: "checkmark")
                                            .accessibilityHidden(true)
                                    }
                                }
                                .font(.title3)
                                .padding(.horizontal, Spacing.md)
                                .frame(minHeight: 56)
                            }
                            .buttonStyle(CarKeyStyle())
                            .disabled(!option.isEnabled)
                            .accessibilityAddTraits(option.isSelected ? .isSelected : [])
                        }
                    }
                }
            }
            .padding(Spacing.sm)
            .background(Color.roadCanvas.ignoresSafeArea())
        }
    }
#endif
