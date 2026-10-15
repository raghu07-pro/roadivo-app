import SwiftUI

struct LanguageView: View {
    @State var viewModel: LanguageViewModel

    var body: some View {
        @Bindable var viewModel = viewModel
        List {
            Section {
                row(name: String(appLocalized: "Follow System"), flag: nil, isSelected: viewModel.selected == nil) {
                    viewModel.choose(nil)
                }
                .accessibilityIdentifier("language.system")
            }
            Section {
                ForEach(viewModel.filtered) { option in
                    row(name: option.name, flag: option.flag, isSelected: viewModel.selected == option.code) {
                        viewModel.choose(option.code)
                    }
                    .accessibilityIdentifier("language.\(option.code)")
                }
            } header: {
                Text("All Languages")
            } footer: {
                Text("Roadivo follows your iPhone's language unless you choose one here.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(.roadCanvas)
        .clearsBottomAccessory()
        .navigationTitle("Language")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $viewModel.query, prompt: Text("Find a language"))
    }

    private func row(name: String, flag: String?, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                if let flag {
                    Text(flag).accessibilityHidden(true)
                }
                Text(name).foregroundStyle(Color.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(.roadAccent)
                }
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    NavigationStack { LanguageView(viewModel: LanguageViewModel()) }
}
