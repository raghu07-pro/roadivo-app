import Foundation
import Observation

/// One profile's settings. Every change is saved at once, so it applies live if that screen is connected.
@Observable
@MainActor
final class DisplayProfileEditorViewModel {
    /// The subtitle picker's three choices; the language is picked separately for On.
    enum SubtitleSetting: Hashable, CaseIterable {
        case automatic
        case off
        case on
    }

    private(set) var profile: DisplayProfile
    /// Sources Home can switch to, without On this iPhone; read by `loadSources()`.
    private(set) var sources: [SourceOption] = []
    private let store: DisplayProfileStore
    private let repository: LibraryRepository

    /// Cheap, as a parent makes one on every redraw (the editor keeps the first); the library is read
    /// once, in `loadSources()`.
    init(profile: DisplayProfile, store: DisplayProfileStore, repository: LibraryRepository) {
        self.profile = profile
        self.store = store
        self.repository = repository
    }

    func loadSources() {
        // Unreadable, the picker offers only "Any Source".
        sources = ((try? repository.playlists()) ?? [])
            .filter { $0.kind != .localVideos }
            .map { SourceOption(id: $0.id, name: $0.name, count: 0) }
    }

    var name: String {
        get { profile.name }
        set { change { $0.name = newValue } }
    }

    /// The source picked for Home; a deleted one reads as "Any Source".
    var preferredSourceID: UUID? {
        get { profile.preferredSourceID.flatMap { id in sources.contains { $0.id == id } ? id : nil } }
        set { change { $0.preferredSourceID = newValue } }
    }

    var aspect: VideoAspect {
        get { profile.aspect }
        set { change { $0.aspect = newValue } }
    }

    var playsNextAutomatically: Bool {
        get { profile.playsNextAutomatically }
        set { change { $0.playsNextAutomatically = newValue } }
    }

    var opensCarMode: Bool {
        get { profile.opensCarMode }
        set { change { $0.opensCarMode = newValue } }
    }

    var subtitleSetting: SubtitleSetting {
        get {
            switch profile.subtitles {
            case .automatic: .automatic
            case .off: .off
            case .on: .on
            }
        }
        set {
            change { profile in
                switch newValue {
                case .automatic: profile.subtitles = .automatic
                case .off: profile.subtitles = .off
                case .on: profile.subtitles = .on(language: Self.appLanguage)
                }
            }
        }
    }

    /// The subtitle language for On, a language code.
    var subtitleLanguage: String {
        get {
            if case let .on(language) = profile.subtitles {
                return language ?? Self.appLanguage
            }
            return Self.appLanguage
        }
        set { change { $0.subtitles = .on(language: newValue) } }
    }

    /// The offered languages, with the app's own first if it isn't among them.
    var subtitleLanguages: [String] {
        SubtitleMode.languages.contains(subtitleLanguage)
            ? SubtitleMode.languages
            : [subtitleLanguage] + SubtitleMode.languages
    }

    /// "Living Room TV" or, before it's renamed, what iOS calls the receiver.
    var title: String {
        let trimmed = profile.name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? (profile.receiver?.name ?? "") : trimmed
    }

    func delete() {
        store.delete(profile.id)
    }

    private func change(_ edit: (inout DisplayProfile) -> Void) {
        edit(&profile)
        store.update(profile)
    }

    private static var appLanguage: String {
        AppLanguage.shared.locale.language.languageCode?.identifier ?? "en"
    }
}
