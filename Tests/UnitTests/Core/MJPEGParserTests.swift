import Foundation
import Testing
@testable import Roadivo

@Suite("Screen Broadcast stream reading")
struct MJPEGParserTests {
    private let first = Data([0xFF, 0xD8, 0x01, 0x02, 0xFF, 0xD9])
    private let second = Data([0xFF, 0xD8, 0x0D, 0x0A, 0x0D, 0x0A, 0xFF, 0xD9])

    private var stream: Data {
        BroadcastHTTP.streamHeader + BroadcastHTTP.part(first) + BroadcastHTTP.part(second)
    }

    @Test("Every frame Screen Broadcast sends comes out whole, even one holding a blank-line pattern")
    func readsEveryFrame() {
        var parser = MJPEGParser()
        #expect(parser.append(stream) == [first, second])
        #expect(!parser.hasFailed)
    }

    @Test("Frames come out the same however the bytes are split on the way")
    func readsSplitBytes() {
        var parser = MJPEGParser()
        let frames = stream.flatMap { parser.append(Data([$0])) }
        #expect(frames == [first, second])
    }

    @Test("A server answering with anything but 200 is not a broadcast")
    func refusesOtherResponses() {
        var parser = MJPEGParser()
        #expect(parser.append(BroadcastHTTP.notFoundResponse).isEmpty)
        #expect(parser.hasFailed)
    }

    @Test("A frame without its length, or one far too large, ends the stream")
    func refusesBrokenParts() {
        var missing = MJPEGParser()
        let part = Data("--roadivo-frame\r\nContent-Type: image/jpeg\r\n\r\n".utf8)
        _ = missing.append(BroadcastHTTP.streamHeader + part)
        #expect(missing.hasFailed)
        var huge = MJPEGParser()
        let header = "--roadivo-frame\r\nContent-Length: \(MJPEGParser.frameLimit + 1)\r\n\r\n"
        _ = huge.append(BroadcastHTTP.streamHeader + Data(header.utf8))
        #expect(huge.hasFailed)
    }
}
