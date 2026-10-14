import SwiftUI
import UIKit

/// A destructive menu label ("Delete") with a red icon as well as the red title the role gives,
/// so the icon doesn't take the accent tint.
struct DestructiveLabel: View {
    let title: LocalizedStringKey
    let systemImage: String

    var body: some View {
        Label {
            Text(title)
        } icon: {
            if let red = UIImage(systemName: systemImage)?.withTintColor(.systemRed, renderingMode: .alwaysOriginal) {
                Image(uiImage: red)
            } else {
                Image(systemName: systemImage)
            }
        }
    }
}

#Preview {
    Menu("Options") {
        Button("Play", systemImage: "play.fill") {}
        Button(role: .destructive) {} label: { DestructiveLabel(title: "Delete", systemImage: "trash") }
    }
    .padding()
}
