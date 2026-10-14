import Foundation
import Testing
@testable import Roadivo

@Suite("Privacy page")
@MainActor
struct PrivacyPolicyTests {
    @Test("The page hosted for the App Store ships in the app")
    func pageIsBundled() throws {
        let html = try page()
        #expect(html.contains("id=\"privacy\""))
        #expect(html.contains("id=\"terms\""))
        #expect(html.contains("id=\"support\""))
        #expect(html.contains("mailto:"))
    }

    @Test("It's one light file: nothing else to upload or download")
    func pageIsSelfContained() throws {
        let html = try page()
        #expect(matches(of: #"(<link[^>]*>)"#, in: html).isEmpty)
        #expect(matches(of: #"(src=)"#, in: html).isEmpty)
        #expect(matches(of: #"(<script|url\()"#, in: html).isEmpty)
        #expect(html.utf8.count < 30000)
    }

    private func page() throws -> String {
        let url = try #require(PrivacyPolicyView.pageURL)
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func matches(of pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            Range(match.range(at: 1), in: text).map { String(text[$0]) }
        }
    }
}
