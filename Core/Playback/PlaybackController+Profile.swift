import AVFoundation

/// The connected screen's display profile, applied to the player (DECISIONS 110–112).
extension PlaybackController {
    func apply(_ profile: DisplayProfile) {
        videoGravity = profile.aspect.gravity
        // An AirPlay receiver may ignore it: Apple documents the property, not that every receiver honours it.
        player.externalPlaybackVideoGravity = profile.aspect.gravity
        playsNextAutomatically = profile.playsNextAutomatically
        if subtitles != profile.subtitles {
            subtitles = profile.subtitles
            applySubtitles()
        }
    }

    /// Picks the playing video's subtitles once its tracks are known. Chosen by hand, not by criteria:
    /// a selection made through `AVPlayer`'s criteria didn't hold on live streams.
    func applySubtitles() {
        guard let item = player.currentItem else { return }
        let mode = subtitles
        let appLanguage = AppLanguage.shared.locale.language.languageCode?.identifier ?? "en"
        subtitleTask?.cancel()
        subtitleTask = Task { [weak self] in
            guard let group = try? await item.asset.loadMediaSelectionGroup(for: .legible),
                  !Task.isCancelled, let self, player.currentItem === item else { return }
            switch mode {
            case .automatic:
                item.selectMediaOptionAutomatically(in: group)
            case .off:
                item.select(nil, in: group)
            case let .on(language):
                let option = SubtitleMode.pick(
                    from: group.options,
                    language: language ?? appLanguage,
                    languageOf: { $0.extendedLanguageTag ?? $0.locale?.language.languageCode?.identifier },
                    isForced: { $0.hasMediaCharacteristic(.containsOnlyForcedSubtitles) }
                )
                item.select(option, in: group)
            }
        }
    }
}
