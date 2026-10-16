import Foundation

/// What a saved car or display connecting does beyond its picture and subtitles: switch Home's source
/// and open Car Mode. Decided apart from the views so it's tested (DECISIONS 110).
struct ReceiverConnectPlan: Equatable {
    let profileID: UUID
    var sourceID: UUID?
    var opensCarMode = false

    /// Nil when nothing should happen: no saved profile, this connection already handled, or the app not free
    /// to act (in the background, or a sheet such as a purchase up). Car Mode opens only over what's playing.
    static func make(
        profile: DisplayProfile?,
        handledProfileID: UUID?,
        canPresent: Bool,
        isPro: Bool,
        isPlaying: Bool
    ) -> ReceiverConnectPlan? {
        guard let profile, !profile.isThisIPhone, profile.id != handledProfileID, canPresent else { return nil }
        return ReceiverConnectPlan(
            profileID: profile.id,
            sourceID: profile.preferredSourceID,
            opensCarMode: profile.opensCarMode && isPro && isPlaying
        )
    }
}
