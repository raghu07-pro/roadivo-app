import SwiftUI

struct HelpView: View {
    @State private var expanded: Set<Int> = []

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.sm) {
                ForEach(FAQEntry.all) { entry in
                    DisclosureGroup(isExpanded: binding(for: entry.id)) {
                        Text(app: entry.answer)
                            .font(Typography.secondary)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, Spacing.xs)
                    } label: {
                        Text(app: entry.question)
                            .font(Typography.cardTitle)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                    }
                    .tint(.secondary)
                    .cardStyle()
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(.roadCanvas)
        .navigationTitle("Help & FAQ")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func binding(for id: Int) -> Binding<Bool> {
        Binding(
            get: { expanded.contains(id) },
            set: { isOpen in
                if isOpen {
                    expanded.insert(id)
                } else {
                    expanded.remove(id)
                }
            }
        )
    }
}

#Preview {
    NavigationStack { HelpView() }
}
