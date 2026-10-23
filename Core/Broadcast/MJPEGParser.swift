import Foundation

/// Reads Screen Broadcast's stream (`BroadcastHTTP.streamHeader`, then one `part` per frame) as bytes arrive in any
/// pieces, and returns each whole JPEG. Pure, so the CarPlay window's mirror is tested without a broadcast.
struct MJPEGParser {
    private enum Stage: Equatable {
        case response
        case partHeader
        case body(length: Int)
        case failed
    }

    /// A frame is a 1280-pixel JPEG, so anything near this is a broken or foreign stream, not a picture.
    static let frameLimit = 8 * 1024 * 1024
    private static let headerLimit = 16 * 1024
    private static let headerEnd = Data("\r\n\r\n".utf8)

    private var stage = Stage.response
    private var buffer = Data()

    /// A stream that isn't Screen Broadcast's; the connection should end.
    var hasFailed: Bool {
        stage == .failed
    }

    mutating func append(_ data: Data) -> [Data] {
        guard !hasFailed else { return [] }
        buffer.append(data)
        var frames: [Data] = []
        while let frame = next() {
            frames.append(frame)
        }
        return frames
    }

    /// The next whole frame, or nil once more bytes are needed or the stream fails.
    private mutating func next() -> Data? {
        while true {
            switch stage {
            case .failed:
                return nil
            case .response:
                guard let header = takeHeader() else { return nil }
                stage = Self.isSuccess(header) ? .partHeader : .failed
            case .partHeader:
                guard let header = takeHeader() else { return nil }
                guard let length = Self.contentLength(in: header), length <= Self.frameLimit else {
                    stage = .failed
                    return nil
                }
                stage = .body(length: length)
            case let .body(length):
                guard buffer.count >= length else { return nil }
                let frame = Data(buffer.prefix(length))
                buffer = Data(buffer.dropFirst(length))
                stage = .partHeader
                return frame
            }
        }
    }

    /// The text before the next blank line, removed from the buffer; a header that never ends fails the stream.
    private mutating func takeHeader() -> String? {
        guard let end = buffer.range(of: Self.headerEnd) else {
            if buffer.count > Self.headerLimit {
                stage = .failed
            }
            return nil
        }
        let header = String(bytes: buffer[buffer.startIndex..<end.lowerBound], encoding: .utf8) ?? ""
        buffer = Data(buffer[end.upperBound...])
        return header
    }

    private static func isSuccess(_ header: String) -> Bool {
        let status = header.split(separator: "\r\n", maxSplits: 1).first ?? ""
        return status.hasPrefix("HTTP/1.") && status.split(separator: " ").dropFirst().first == "200"
    }

    private static func contentLength(in header: String) -> Int? {
        for line in header.split(separator: "\r\n") {
            let parts = line.split(separator: ":", maxSplits: 1)
            if parts.count == 2, parts[0].trimmingCharacters(in: .whitespaces).lowercased() == "content-length" {
                return Int(parts[1].trimmingCharacters(in: .whitespaces))
            }
        }
        return nil
    }
}
