import Foundation
import Testing
@testable import PlayCarTV

@Suite("Is Screen Broadcast running")
struct BroadcastProbeTests {
    @Test("A broadcast that answers its page on loopback counts as running", .timeLimit(.minutes(1)))
    func answeringBroadcast() async throws {
        let server = try LoopbackBroadcast(answers: ["/test": BroadcastHTTP.pageResponse(code: "test")])
        let port = await server.start()
        #expect(await BroadcastProbe.isRunning(port: port, path: "/test"))
        server.stop()
    }

    @Test(
        "Nothing listening, or something that isn't PlayCarTV's broadcast, counts as no broadcast",
        .timeLimit(.minutes(1))
    )
    func noBroadcast() async throws {
        let other = try LoopbackBroadcast(answers: ["/test": BroadcastHTTP.notFoundResponse])
        let port = await other.start()
        #expect(await BroadcastProbe.isRunning(port: port, path: "/test") == false)
        #expect(await BroadcastProbe.isRunning(port: port, path: "/elsewhere") == false)
        other.stop()
        #expect(await BroadcastProbe.isRunning(port: port, path: "/test") == false)
    }
}
