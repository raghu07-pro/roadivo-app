import Foundation
import Observation

@Observable
@MainActor
final class OnboardingViewModel {
    let pages = OnboardingPage.all
    var currentIndex = 0
    private let onFinish: () -> Void

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }

    var isLastPage: Bool {
        currentIndex >= pages.count - 1
    }

    func advance() {
        if isLastPage {
            onFinish()
        } else {
            currentIndex += 1
        }
    }

    func skip() {
        onFinish()
    }
}
