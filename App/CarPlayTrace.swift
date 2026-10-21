import Foundation
import OSLog

/// Debug builds only: each CarPlay step in Caches/CarPlayTrace.log, which can be copied off a device (DECISIONS 137).
enum CarPlayTrace {
    private static let logger = Logger(subsystem: "com.roadivo", category: "CarPlay")

    static func write(_ line: String) {
        #if DEBUG
            logger.notice("Trace: \(line, privacy: .public)")
            guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            else { return }
            let file = caches.appending(path: "CarPlayTrace.log")
            let stamped = Data("\(Date().formatted(.iso8601)) \(line)\n".utf8)
            // A trace that can't be written is only a missing diagnostic, never a reason to stop CarPlay.
            if let handle = try? FileHandle(forWritingTo: file) {
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: stamped)
                try? handle.close()
            } else {
                try? stamped.write(to: file)
            }
        #endif
    }
}
