import SwiftUI

extension View {
    /// A ? in the navigation bar that opens a page's steps in a sheet, so the page itself stays short
    /// (owner, 2026-10-20; DECISIONS 128). `identifier` prefixes the button (`.help`), steps and Done.
    func stepsHelp(
        identifier: String,
        steps: [LocalizedStringResource],
        note: LocalizedStringResource? = nil
    ) -> some View {
        modifier(StepsHelp(identifier: identifier, steps: steps, note: note))
    }
}

private struct StepsHelp: ViewModifier {
    let identifier: String
    let steps: [LocalizedStringResource]
    let note: LocalizedStringResource?

    @State private var isShowing = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowing = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    .accessibilityLabel(Text("How It Works"))
                    .accessibilityIdentifier("\(identifier).help")
                }
            }
            .sheet(isPresented: $isShowing) {
                StepsSheet(identifier: identifier, steps: steps, note: note)
            }
    }
}

/// The numbered steps and their note, half height first and pulled up for more; ✕ closes it.
private struct StepsSheet: View {
    let identifier: String
    let steps: [LocalizedStringResource]
    let note: LocalizedStringResource?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        ForEach(steps.indices, id: \.self) { index in
                            GuideStep(number: index + 1, text: steps[index])
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("\(identifier).steps")
                    if let note {
                        Text(app: note)
                            .font(Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(Spacing.md)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .background(.roadCanvas)
            .navigationTitle("How It Works")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // An ✕, as Add a Source closes: a text button in the bar keeps one size whatever the text size.
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: { Label("Close", systemImage: "xmark") }
                        .accessibilityIdentifier("\(identifier).done")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    NavigationStack {
        Color.clear
            .stepsHelp(identifier: "preview", steps: ["Play a video in any app that has an AirPlay button."])
    }
}
