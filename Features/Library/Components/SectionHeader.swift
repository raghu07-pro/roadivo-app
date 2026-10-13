import SwiftUI

/// A Home section header: the section title with its channel count, plus an
/// optional trailing control ("See All").
struct SectionHeader<Trailing: View>: View {
    let title: String
    let count: Int
    var systemImage: String?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .center) {
            SectionTitle(title: title, detail: String(appLocalized: "\(count) channels"), systemImage: systemImage)
            Spacer(minLength: Spacing.sm)
            trailing
        }
    }
}
