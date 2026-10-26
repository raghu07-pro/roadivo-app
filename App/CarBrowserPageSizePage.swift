#if DEBUG
    import SwiftUI

    /// Page size for the open tab, from the bar's AA: a small menu at the top right, as CarTV's, with the size,
    /// Zoom out, Zoom in and Actual Size. It stays open while the page resizes; a tap beside it closes it
    /// (DECISIONS 163).
    struct CarBrowserPageSizePage: View {
        let model: CarScreenModel

        /// Each step, as a share of the page's size.
        private static let step: CGFloat = 0.1

        var body: some View {
            ZStack(alignment: .topTrailing) {
                // Beside the menu: the page shows through, and a tap closes the menu.
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture { model.actions?.closePage() }
                VStack(alignment: .leading, spacing: 0) {
                    Text(Double(model.pageSize).formatted(.percent.precision(.fractionLength(0))))
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                    item("minus", title: "Zoom out", enabled: model.pageSize > 0.51) {
                        model.pageSize - Self.step
                    }
                    item("plus", title: "Zoom in", enabled: model.pageSize < 1.99) { model.pageSize + Self.step }
                    item("arrow.counterclockwise", title: "Actual Size", enabled: abs(model.pageSize - 1) > 0.01) {
                        1
                    }
                }
                .padding(.vertical, Spacing.xs)
                .frame(width: 260)
                .carGlass(in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                .padding(.top, Spacing.xs)
                .padding(.trailing, Spacing.sm)
            }
        }

        private func item(
            _ symbol: String,
            title: LocalizedStringResource,
            enabled: Bool,
            size: @escaping () -> CGFloat
        ) -> some View {
            Button {
                model.actions?.setPageSize(size())
            } label: {
                Label {
                    Text(app: title)
                } icon: {
                    Image(systemName: symbol)
                }
                .font(.title3)
                .padding(.horizontal, Spacing.md)
                .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!enabled)
            .opacity(enabled ? 1 : 0.4)
        }
    }
#endif
