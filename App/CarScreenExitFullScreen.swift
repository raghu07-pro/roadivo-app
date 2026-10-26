#if DEBUG
    import SwiftUI

    /// In full screen, the one control left over the page: brings the bar back.
    struct CarScreenExitFullScreen: View {
        let model: CarScreenModel

        var body: some View {
            Button {
                model.actions?.setBrowserFullScreen(false)
            } label: {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
                    .font(.title2)
                    .frame(width: 56, height: 56)
            }
            .buttonStyle(CarControlStyle(shape: .circle))
            .accessibilityLabel(Text(app: "Exit full screen"))
        }
    }
#endif
