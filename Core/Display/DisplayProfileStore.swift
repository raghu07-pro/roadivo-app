import Foundation
import Observation
import OSLog

/// This iPhone's profile and the saved cars and displays, kept on the device in UserDefaults.
@Observable
@MainActor
final class DisplayProfileStore {
    private(set) var thisIPhone: DisplayProfile
    /// Saved cars and displays, oldest first.
    private(set) var saved: [DisplayProfile]
    /// Called after any change, so the active profile is applied again.
    @ObservationIgnored var onChange: (() -> Void)?

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let logger = Logger(subsystem: "com.roadivo", category: "Profiles")
    private static let key = "roadivo.displayProfiles"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        var stored: [DisplayProfile]?
        if let data = defaults.data(forKey: Self.key) {
            // A profile that can't be read is skipped, never costing the others.
            stored = (try? JSONDecoder().decode([Lenient].self, from: data))?.compactMap(\.profile)
            if stored == nil {
                // Not a list at all: kept aside, as the next save would overwrite it.
                defaults.set(data, forKey: Self.key + ".unreadable")
                Logger(subsystem: "com.roadivo", category: "Profiles")
                    .fault("Saved profiles were unreadable; starting from the defaults")
            }
        }
        thisIPhone = stored?.first(where: \.isThisIPhone) ?? .thisIPhone()
        saved = stored?.filter { !$0.isThisIPhone } ?? []
    }

    /// The saved profile for `receiver`: by iOS's id first, then by name, as the id may change but two
    /// receivers can share a name.
    func savedProfile(for receiver: Receiver?) -> DisplayProfile? {
        guard let receiver else { return nil }
        return saved.first { $0.receiver.map { $0.kind == receiver.kind && $0.uid == receiver.uid } ?? false }
            ?? saved.first { $0.receiver.map(receiver.matches) ?? false }
    }

    /// What applies now: the receiver's profile, or This iPhone's.
    func profile(for receiver: Receiver?) -> DisplayProfile {
        savedProfile(for: receiver) ?? thisIPhone
    }

    func profile(id: UUID) -> DisplayProfile? {
        id == thisIPhone.id ? thisIPhone : saved.first { $0.id == id }
    }

    /// Saves a profile for `receiver`, from This iPhone's settings, or returns the one already saved.
    @discardableResult
    func addProfile(for receiver: Receiver) -> DisplayProfile {
        if let existing = savedProfile(for: receiver) {
            return existing
        }
        let profile = DisplayProfile.new(for: receiver, from: thisIPhone)
        saved.append(profile)
        persist()
        return profile
    }

    func update(_ profile: DisplayProfile) {
        if profile.id == thisIPhone.id {
            thisIPhone = profile
        } else if let index = saved.firstIndex(where: { $0.id == profile.id }) {
            saved[index] = profile
        } else {
            return
        }
        persist()
    }

    func delete(_ id: UUID) {
        saved.removeAll { $0.id == id }
        persist()
    }

    /// One saved profile, or nil when it can't be read.
    private struct Lenient: Decodable {
        let profile: DisplayProfile?

        init(from decoder: Decoder) throws {
            profile = try? DisplayProfile(from: decoder) // Skipped, so the rest still load.
        }
    }

    private func persist() {
        do {
            try defaults.set(JSONEncoder().encode([thisIPhone] + saved), forKey: Self.key)
        } catch {
            logger.error("Saving profiles failed: \(error.localizedDescription, privacy: .public)")
        }
        onChange?()
    }
}
