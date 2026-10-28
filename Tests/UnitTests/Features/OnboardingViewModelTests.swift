import Testing
@testable import PlayCarTV

@Suite("Onboarding")
@MainActor
struct OnboardingViewModelTests {
    @Test("Continue walks the four pages, then finishes once")
    func advance() {
        var finished = 0
        let viewModel = OnboardingViewModel { finished += 1 }
        #expect(viewModel.pages.count == 4)
        #expect(!viewModel.isLastPage)

        viewModel.advance()
        viewModel.advance()
        viewModel.advance()
        #expect(viewModel.isLastPage)
        #expect(finished == 0)

        viewModel.advance()
        #expect(finished == 1)
    }

    @Test("Skip finishes from any page")
    func skip() {
        var finished = false
        let viewModel = OnboardingViewModel { finished = true }
        viewModel.skip()
        #expect(finished)
    }
}
