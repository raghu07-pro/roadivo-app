import SwiftUI
import UIKit

/// The label for a destructive menu action ("Delete"): the title and its icon
/// both red. The role colours the title; the icon is drawn red here so it
/// doesn't take the app's accent tint.
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
