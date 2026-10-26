#if DEBUG
    import SwiftUI

    /// The car browser's tabs, laid out like CarTV's (DECISIONS 163): a card for each tab with its picture, title and
    /// a close button, the open one outlined; New tab, how many are open, and Done along the bottom.
    struct CarBrowserTabsPage: View {
        let model: CarScreenModel

        var body: some View {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text(app: "Tabs")
                    .font(.title2.bold())
                GeometryReader { proxy in
                    // Three cards across, as in CarTV; the rest scroll.
                    let width = (proxy.size.width - Spacing.md * 2) / 3
                    ScrollView(.horizontal) {
                        HStack(alignment: .top, spacing: Spacing.md) {
                            ForEach(model.tabs) { card($0, width: width) }
                        }
                    }
                    .scrollIndicators(.hidden)
                }
                HStack {
                    Button {
                        model.actions?.newTab()
                    } label: {
                        Image(systemName: "plus")
                            .font(.title2.weight(.semibold))
                            .frame(width: 56, height: 56)
                    }
                    .buttonStyle(CarBarButtonStyle())
                    .disabled(!model.canAddTab)
                    .accessibilityLabel(Text(app: "New tab"))
                    Spacer()
                    Text(String(model.tabs.count) + " / " + String(CarBrowserSession.maximumTabs))
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        model.actions?.closePage()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .background(.blue, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(app: "Done"))
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background { CarScreenWallpaper() }
        }

        private func card(_ tab: CarScreenModel.BrowserTab, width: CGFloat) -> some View {
            let shape = RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
            return VStack(spacing: Spacing.sm) {
                Button {
                    model.actions?.selectTab(tab.id)
                } label: {
                    Group {
                        if let snapshot = tab.snapshot {
                            Image(uiImage: snapshot)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Image(systemName: "globe")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .frame(width: width, height: width * 9 / 16, alignment: .top)
                    .background(Color(.systemBackground))
                    .clipShape(shape)
                    .overlay(shape.strokeBorder(tab.isSelected ? Color.blue : .clear, lineWidth: 4))
                }
                .buttonStyle(.plain)
                .overlay(alignment: .topTrailing) {
                    Button {
                        model.actions?.closeTab(tab.id)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title3.weight(.semibold))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(CarBarButtonStyle())
                    .padding(Spacing.xs)
                    .accessibilityLabel(Text(app: "Close tab"))
                }
                .accessibilityAddTraits(tab.isSelected ? .isSelected : [])
                Text(tab.title)
                    .font(.headline)
                    .lineLimit(1)
                    .frame(width: width)
            }
        }
    }
#endif
