import Foundation

/// The newest Roadivo on the App Store, for the "New Version Available" prompt.
struct AppRelease: Equatable, Sendable {
    let version: String
    let notes: String
    let storeURL: URL
}

/// Where the newest version comes from: the App Store live, nothing in UI tests.
protocol AppUpdateChecking: Sendable {
    func latestRelease() async throws -> AppRelease?
}

enum AppVersion {
    static var current: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    /// Compares numerically, part by part: "1.10" is newer than "1.9", and "1.2" equals "1.2.0".
    static func isNewer(_ candidate: String, than current: String) -> Bool {
        let new = parts(candidate)
        let old = parts(current)
        for index in 0..<max(new.count, old.count) {
            let lhs = index < new.count ? new[index] : 0
            let rhs = index < old.count ? old[index] : 0
            if lhs != rhs {
                return lhs > rhs
            }
        }
        return false
    }

    private static func parts(_ version: String) -> [Int] {
        version.split(separator: ".").map { Int($0.prefix { $0.isNumber }) ?? 0 }
    }
}
