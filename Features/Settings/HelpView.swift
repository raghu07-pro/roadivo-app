import SwiftUI

struct HelpView: View {
    @State private var expanded: Set<Int> = []
    @Environment(\.openURL) private var openURL

    /// Opens the user's mail app addressed to support, with the subject filled in.
    private static let supportMail = URL(string: "mailto:dhavalbhanderi880@gmail.com?subject=Roadivo%20support")

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
                if let mail = Self.supportMail {
                    contactSupport(mail)
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

    private func contactSupport(_ mail: URL) -> some View {
        Button { openURL(mail) } label: {
            HStack(spacing: Spacing.sm) {
                IconTile(systemImage: "envelope.fill")
                Text("Contact Support")
                    .font(Typography.cardTitle)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                // Mail opens outside Roadivo.
                Image(systemName: "arrow.up.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.roadMuted)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .cardStyle()
        }
        .buttonStyle(PressableStyle())
        .padding(.top, Spacing.xs)
        .accessibilityIdentifier("help.contactSupport")
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

#Preview("Dark, largest text") {
    NavigationStack { HelpView() }
        .preferredColorScheme(.dark)
        .environment(\.dynamicTypeSize, .accessibility3)
}
