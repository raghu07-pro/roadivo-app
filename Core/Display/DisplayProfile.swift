import AVFoundation

/// Settings kept for one car or display, or for This iPhone when `receiver` is nil (DECISIONS 110).
struct DisplayProfile: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var name: String
    let receiver: Receiver?
    /// The source Home shows when the receiver connects; nil leaves Home as it is.
    var preferredSourceID: UUID?
    var aspect: VideoAspect = .fit
    var playsNextAutomatically = true
    /// Starts Car Mode when the receiver connects (Pro).
    var opensCarMode = false
    var subtitles: SubtitleMode = .automatic

    var isThisIPhone: Bool {
        receiver == nil
    }

    /// This iPhone's profile, with today's behaviour: fit, next video plays, iOS picks subtitles.
    static func thisIPhone() -> DisplayProfile {
        DisplayProfile(id: UUID(), name: "", receiver: nil)
    }

    /// A new profile for `receiver`, starting from `defaults` (This iPhone's settings).
    static func new(for receiver: Receiver, from defaults: DisplayProfile) -> DisplayProfile {
        var profile = DisplayProfile(id: UUID(), name: receiver.name, receiver: receiver)
        profile.aspect = defaults.aspect
        profile.playsNextAutomatically = defaults.playsNextAutomatically
        profile.subtitles = defaults.subtitles
        return profile
    }
}

extension DisplayProfile {
    private enum CodingKeys: String, CodingKey {
        case id, name, receiver, preferredSourceID, aspect, playsNextAutomatically, opensCarMode, subtitles
    }

    /// Missing or unknown settings take their defaults (`try?` on purpose), so a profile saved by an older or
    /// newer version still reads; only one without an id or with an unreadable receiver fails.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = (try? container.decodeIfPresent(String.self, forKey: .name)) ?? ""
        receiver = try container.decodeIfPresent(Receiver.self, forKey: .receiver)
        preferredSourceID = try? container.decodeIfPresent(UUID.self, forKey: .preferredSourceID)
        aspect = (try? container.decodeIfPresent(VideoAspect.self, forKey: .aspect)) ?? .fit
        playsNextAutomatically = (try? container.decodeIfPresent(Bool.self, forKey: .playsNextAutomatically)) ?? true
        opensCarMode = (try? container.decodeIfPresent(Bool.self, forKey: .opensCarMode)) ?? false
        subtitles = (try? container.decodeIfPresent(SubtitleMode.self, forKey: .subtitles)) ?? .automatic
    }
}

/// How the picture meets the screen.
enum VideoAspect: String, Codable, CaseIterable, Sendable {
    /// The whole picture, with bars if the shapes differ.
    case fit
    /// Covers the screen, cropping the edges.
    case fill
    /// Covers the screen without cropping, so the picture is squashed or widened.
    case stretch

    var gravity: AVLayerVideoGravity {
        switch self {
        case .fit: .resizeAspect
        case .fill: .resizeAspectFill
        case .stretch: .resize
        }
    }
}

/// Which subtitles play. `automatic` is iOS's choice (Settings › Accessibility › Subtitles & Captioning).
enum SubtitleMode: Hashable, Codable, Sendable {
    case automatic
    case off
    /// A language code ("en"); nil is the app's language.
    case on(language: String?)

    /// The subtitles to show from `options`: the language asked for, else the first full set. Forced
    /// subtitles (just the foreign lines) never stand in for a full set.
    static func pick<Option>(
        from options: [Option],
        language: String,
        languageOf: (Option) -> String?,
        isForced: (Option) -> Bool
    ) -> Option? {
        let full = options.filter { !isForced($0) }
        let wanted = language.lowercased()
        let match = full.first { option in
            guard let code = languageOf(option)?.lowercased() else { return false }
            return code == wanted || code.hasPrefix(wanted + "-")
        }
        return match ?? full.first
    }

    /// Languages offered for subtitles: the ones most often found in films and on IPTV.
    static let languages = [
        "en", "es", "fr", "de", "it", "pt", "nl", "sv", "pl", "tr", "ru", "uk",
        "ar", "he", "hi", "ja", "ko", "zh", "th", "vi", "id"
    ]
}
