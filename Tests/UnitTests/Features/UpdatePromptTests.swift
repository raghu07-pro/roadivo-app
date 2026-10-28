import Foundation
import Testing
@testable import PlayCarTV

@Suite("Update prompt")
@MainActor
struct UpdatePromptTests {
    private let store = URL(string: "https://apps.apple.com/app/id123") ?? URL(filePath: "/")

    private func defaults() -> UserDefaults {
        let name = "update-tests-\(UUID().uuidString)"
        return UserDefaults(suiteName: name) ?? .standard
    }

    @Test("Versions compare part by part, numerically")
    func versions() {
        #expect(AppVersion.isNewer("1.10.0", than: "1.9.3"))
        #expect(AppVersion.isNewer("2.0", than: "1.9.9"))
        #expect(!AppVersion.isNewer("1.2", than: "1.2.0"))
        #expect(!AppVersion.isNewer("1.0.0", than: "1.0.1"))
    }

    @Test("A newer App Store version shows the prompt")
    func newerShows() async {
        let model = UpdatePromptModel(
            checker: FakeChecker(version: "1.1.0", store: store),
            defaults: defaults(),
            currentVersion: "1.0.0"
        )
        await model.check()
        #expect(model.release?.version == "1.1.0")
    }

    @Test("The same or an older version shows nothing")
    func sameIsQuiet() async {
        let model = UpdatePromptModel(
            checker: FakeChecker(version: "1.0.0", store: store),
            defaults: defaults(),
            currentVersion: "1.0.0"
        )
        await model.check()
        #expect(model.release == nil)
    }

    @Test("A closed version isn't offered again; Update Now asks again another day")
    func closeRemembersVersion() async {
        let store = defaults()
        var clock = Date(timeIntervalSince1970: 0)
        let checker = FakeChecker(version: "1.1.0", store: self.store)
        let model = UpdatePromptModel(checker: checker, defaults: store, currentVersion: "1.0.0", now: { clock })
        await model.check()
        model.close()
        clock.addTimeInterval(2 * 86400)
        await model.check()
        #expect(model.release == nil)

        let other = UpdatePromptModel(checker: checker, defaults: defaults(), currentVersion: "1.0.0", now: { clock })
        await other.check()
        #expect(other.openStore() == self.store)
        #expect(other.release == nil)
    }

    @Test("The App Store is asked at most once a day")
    func onceADay() async {
        let store = defaults()
        let checker = FakeChecker(version: "1.1.0", store: self.store)
        let model = UpdatePromptModel(
            checker: checker,
            defaults: store,
            currentVersion: "1.0.0",
            now: { Date(timeIntervalSince1970: 0) }
        )
        await model.check()
        _ = model.openStore()
        await model.check()
        #expect(checker.calls == 1)
    }

    @Test("Apple's lookup reply becomes a release; an unknown app is none")
    func lookupDecoding() async throws {
        let reply = """
        {"resultCount":1,"results":[{"version":"1.2.0","releaseNotes":"Faster.","trackViewUrl":"https://apps.apple.com/app/id9"}]}
        """
        let checker = AppStoreUpdateChecker(bundleID: "net.example.app", country: "US") { request in
            #expect(request.url?.query()?.contains("bundleId=net.example.app") == true)
            let response = HTTPURLResponse(
                url: request.url ?? URL(filePath: "/"),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )
            return (Data(reply.utf8), response ?? URLResponse())
        }
        let release = try await checker.latestRelease()
        #expect(release?.version == "1.2.0")
        #expect(release?.notes == "Faster.")

        let empty = AppStoreUpdateChecker(bundleID: "x", country: "US") { request in
            let response = HTTPURLResponse(
                url: request.url ?? URL(filePath: "/"),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )
            return (Data(#"{"resultCount":0,"results":[]}"#.utf8), response ?? URLResponse())
        }
        #expect(try await empty.latestRelease() == nil)
    }
}

/// Counts lookups and answers with one fixed version.
private final class FakeChecker: AppUpdateChecking, @unchecked Sendable {
    let version: String
    let store: URL
    private let lock = NSLock()
    private var count = 0

    var calls: Int {
        lock.withLock { count }
    }

    init(version: String, store: URL) {
        self.version = version
        self.store = store
    }

    func latestRelease() async throws -> AppRelease? {
        lock.withLock { count += 1 }
        return AppRelease(version: version, notes: "", storeURL: store)
    }
}
