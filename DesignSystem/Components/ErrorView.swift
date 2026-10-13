import SwiftUI

struct ErrorView: View {
    let message: String
    var retry: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label("Something went wrong", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            if let retry {
                PrimaryButton(title: "Try Again", systemImage: "arrow.clockwise", isCompact: true, action: retry)
            }
        }
    }
}
