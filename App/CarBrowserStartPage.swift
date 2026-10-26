#if DEBUG
    import SwiftUI

    /// The browser's Start Page, from the bar's house and in a new tab: saved pages and every site, filling the
    /// browser under its bar as CarTV's home does, and opening in the current tab (DECISIONS 163).
    struct CarBrowserStartPage: View {
        let model: CarScreenModel

        var body: some View {
            CarScreenSitesView(model: model)
                .padding(Spacing.md)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground).ignoresSafeArea())
        }
    }
#endif
