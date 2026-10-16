import AVFoundation
import Foundation
import Testing
@testable import Roadivo

@Suite("Display profiles")
@MainActor
struct DisplayProfileTests {
    private let livingRoom = Receiver(kind: .airPlay, uid: "AA:BB-airplay", name: "Living Room TV")

    private func freshDefaults() throws -> UserDefaults {
        let name = "roadivo.tests.\(UUID().uuidString)"
        return try #require(UserDefaults(suiteName: name))
    }

    @Test("The receiver is the AirPlay display first, then CarPlay, then a wired display; never Bluetooth")
    func receiverFromRoute() {
        let airPlay = RouteOutput(.airPlay, "Living Room TV", uid: "AA:BB-airplay")
        let car = RouteOutput(.carAudio, "CarPlay")
        let wired = RouteOutput(.HDMI, "HDMI")

        #expect(Receiver.current(in: [car, wired, airPlay]) == livingRoom)
        #expect(Receiver.current(in: [wired, car])?.kind == .carPlay)
        #expect(Receiver.current(in: [wired])?.kind == .wired)
        #expect(Receiver.current(in: [RouteOutput(.bluetoothA2DP, "Car Kit")]) == nil)
        #expect(Receiver.current(in: [RouteOutput(.builtInSpeaker, "Speaker")]) == nil)
    }

    @Test("A receiver is recognised by its id, or by its name when iOS gives it a new id")
    func matching() {
        #expect(livingRoom.matches(Receiver(kind: .airPlay, uid: "new-id", name: "Living Room TV")))
        #expect(livingRoom.matches(Receiver(kind: .airPlay, uid: "AA:BB-airplay", name: "Renamed TV")))
        #expect(!livingRoom.matches(Receiver(kind: .airPlay, uid: "other", name: "Kitchen TV")))
        #expect(!livingRoom.matches(Receiver(kind: .wired, uid: "AA:BB-airplay", name: "Living Room TV")))
    }

    @Test("A new store holds only This iPhone, with today's behaviour")
    func startsWithThisIPhone() throws {
        let store = try DisplayProfileStore(defaults: freshDefaults())
        #expect(store.saved.isEmpty)
        #expect(store.thisIPhone.isThisIPhone)
        #expect(store.thisIPhone.aspect == .fit)
        #expect(store.thisIPhone.playsNextAutomatically)
        #expect(store.thisIPhone.subtitles == .automatic)
        #expect(store.profile(for: livingRoom).id == store.thisIPhone.id)
    }

    @Test("A receiver's profile starts from This iPhone's settings, named after it, and is saved once")
    func addProfile() throws {
        let store = try DisplayProfileStore(defaults: freshDefaults())
        var phone = store.thisIPhone
        phone.aspect = .fill
        phone.subtitles = .on(language: "fr")
        store.update(phone)

        let profile = store.addProfile(for: livingRoom)

        #expect(profile.name == "Living Room TV")
        #expect(profile.aspect == .fill)
        #expect(profile.subtitles == .on(language: "fr"))
        #expect(store.addProfile(for: livingRoom).id == profile.id)
        #expect(store.saved.count == 1)
        #expect(store.profile(for: livingRoom).id == profile.id)
    }

    @Test("Profiles survive a relaunch, and a deleted one hands back to This iPhone")
    func persistence() throws {
        let defaults = try freshDefaults()
        let store = DisplayProfileStore(defaults: defaults)
        var profile = store.addProfile(for: livingRoom)
        profile.name = "Lounge"
        profile.subtitles = .on(language: "ja")
        profile.playsNextAutomatically = false
        store.update(profile)

        let relaunched = DisplayProfileStore(defaults: defaults)
        #expect(relaunched.saved == [profile])
        #expect(relaunched.thisIPhone == store.thisIPhone)

        relaunched.delete(profile.id)
        #expect(DisplayProfileStore(defaults: defaults).profile(for: livingRoom).isThisIPhone)
    }

    @Test("Unreadable saved profiles start again from today's behaviour")
    func unreadable() throws {
        let defaults = try freshDefaults()
        defaults.set(Data("not json".utf8), forKey: "roadivo.displayProfiles")
        let store = DisplayProfileStore(defaults: defaults)
        #expect(store.saved.isEmpty)
        #expect(store.thisIPhone.aspect == .fit)
    }

    @Test("Every change reports itself, so the profile in use is applied again")
    func reportsChanges() throws {
        let store = try DisplayProfileStore(defaults: freshDefaults())
        var changes = 0
        store.onChange = { changes += 1 }
        let profile = store.addProfile(for: livingRoom)
        store.update(profile)
        store.delete(profile.id)
        #expect(changes == 3)
    }

    @Test("A USB-C (DisplayPort) display counts as a wired display")
    func displayPort() {
        #expect(Receiver.current(in: [RouteOutput(.displayPort, "Studio Display")])?.kind == .wired)
    }

    @Test("Two receivers with the same name each get their own profile, matched by id first")
    func sameNameReceivers() throws {
        let defaults = try freshDefaults()
        let first = DisplayProfile.new(
            for: Receiver(kind: .airPlay, uid: "tv-1", name: "Apple TV"),
            from: .thisIPhone()
        )
        var second = DisplayProfile.new(
            for: Receiver(kind: .airPlay, uid: "tv-2", name: "Apple TV"),
            from: .thisIPhone()
        )
        second.aspect = .stretch
        try defaults.set(
            JSONEncoder().encode([DisplayProfile.thisIPhone(), first, second]),
            forKey: "roadivo.displayProfiles"
        )

        let store = DisplayProfileStore(defaults: defaults)

        #expect(store.profile(for: Receiver(kind: .airPlay, uid: "tv-2", name: "Apple TV")).id == second.id)
        #expect(store.profile(for: Receiver(kind: .airPlay, uid: "tv-1", name: "Apple TV")).id == first.id)
        // A new id under a known name still finds a profile, as iOS may change the id.
        #expect(!store.profile(for: Receiver(kind: .airPlay, uid: "tv-9", name: "Apple TV")).isThisIPhone)
    }

    @Test("A profile saved by another version reads, with missing or unknown settings at their defaults")
    func tolerantDecoding() throws {
        let defaults = try freshDefaults()
        let id = UUID()
        let json = """
        [{"id":"\(id.uuidString)","name":"Car","receiver":{"kind":"carPlay","uid":"c","name":"CarPlay"},
          "aspect":"zoom","futureSetting":42},
         {"name":"no id"}]
        """
        defaults.set(Data(json.utf8), forKey: "roadivo.displayProfiles")

        let store = DisplayProfileStore(defaults: defaults)

        #expect(store.saved.map(\.id) == [id])
        #expect(store.saved.first?.aspect == .fit)
        #expect(store.saved.first?.playsNextAutomatically == true)
        #expect(store.saved.first?.subtitles == .automatic)
    }

    @Test("Saved data that isn't a list at all is kept aside, not overwritten")
    func unreadableKeptAside() throws {
        let defaults = try freshDefaults()
        defaults.set(Data("not json".utf8), forKey: "roadivo.displayProfiles")
        _ = DisplayProfileStore(defaults: defaults)
        #expect(defaults.data(forKey: "roadivo.displayProfiles.unreadable") == Data("not json".utf8))
    }

    @Test("Connecting acts once: Home's source, and Car Mode only over something playing, for Pro")
    func connectPlan() {
        var profile = DisplayProfile.new(for: livingRoom, from: .thisIPhone())
        profile.preferredSourceID = UUID()
        profile.opensCarMode = true
        let plan = { (handled: UUID?, canPresent: Bool, isPro: Bool, isPlaying: Bool) in
            ReceiverConnectPlan.make(
                profile: profile,
                handledProfileID: handled,
                canPresent: canPresent,
                isPro: isPro,
                isPlaying: isPlaying
            )
        }

        #expect(plan(nil, true, true, true) == ReceiverConnectPlan(
            profileID: profile.id, sourceID: profile.preferredSourceID, opensCarMode: true
        ))
        #expect(plan(nil, true, true, false)?.opensCarMode == false) // Never starts a video by itself.
        #expect(plan(nil, true, false, true)?.opensCarMode == false) // Car Mode is Pro.
        #expect(plan(profile.id, true, true, true) == nil) // Already handled: a route that came back.
        #expect(plan(nil, false, true, true) == nil) // Backgrounded, or a purchase sheet is up.
        #expect(ReceiverConnectPlan.make(
            profile: nil, handledProfileID: nil, canPresent: true, isPro: true, isPlaying: true
        ) == nil)
    }

    @Test("Subtitles: the language asked for, a regional variant counts, never forced-only")
    func pickSubtitles() {
        let options: [(code: String?, forced: Bool)] = [("fr", true), ("en-US", false), ("fr", false), (nil, false)]
        let pick = { (language: String) in
            SubtitleMode.pick(from: options, language: language, languageOf: \.code, isForced: \.forced)
        }
        #expect(pick("fr")?.code == "fr" && pick("fr")?.forced == false)
        #expect(pick("en")?.code == "en-US")
        #expect(pick("ja")?.code == "en-US") // None in Japanese: the first full set.
        #expect(SubtitleMode.pick(
            from: [(code: "fr", forced: true)],
            language: "fr",
            languageOf: \.code,
            isForced: \.forced
        ) == nil)
    }

    @Test("Each aspect ratio maps to the matching video gravity")
    func gravity() {
        #expect(VideoAspect.fit.gravity == .resizeAspect)
        #expect(VideoAspect.fill.gravity == .resizeAspectFill)
        #expect(VideoAspect.stretch.gravity == .resize)
    }

    @Test("The car connection reports a new receiver once, and again when it goes")
    func receiverChanges() {
        let connection = CarConnection()
        var reported: [Receiver?] = []
        connection.onReceiverChange = { reported.append($0) }

        connection.apply([RouteOutput(.airPlay, "Living Room TV", uid: "AA:BB-airplay")])
        connection.apply([RouteOutput(.airPlay, "Living Room TV", uid: "AA:BB-airplay")])
        connection.apply([RouteOutput(.builtInSpeaker, "Speaker")])

        #expect(reported == [livingRoom, nil])
    }

    @Test("The connected screen's profile reaches the player, and This iPhone's once it goes")
    func appliedToPlayer() throws {
        let library = try TestLibrary()
        let store = try DisplayProfileStore(defaults: freshDefaults())
        var profile = store.addProfile(for: livingRoom)
        profile.aspect = .fill
        profile.playsNextAutomatically = false
        store.update(profile)
        let environment = try AppEnvironment(
            apiClient: nil,
            store: SwiftDataStore(inMemory: true),
            secureStore: InMemorySecureStore(),
            fetcher: library.fetcher,
            mediaServers: library.mediaServer,
            storeClient: FakeStoreClient(isPro: false),
            preferences: Preferences(defaults: freshDefaults()),
            displayProfiles: store
        )

        environment.carConnection.apply([RouteOutput(.airPlay, "Living Room TV", uid: "AA:BB-airplay")])
        #expect(environment.playback.videoGravity == .resizeAspectFill)
        #expect(environment.playback.player.externalPlaybackVideoGravity == .resizeAspectFill)
        #expect(!environment.playback.playsNextAutomatically)

        profile.aspect = .stretch
        store.update(profile) // Edited while connected: applies at once.
        #expect(environment.playback.videoGravity == .resize)

        environment.carConnection.apply([RouteOutput(.builtInSpeaker, "Speaker")])
        #expect(environment.playback.videoGravity == .resizeAspect)
        #expect(environment.playback.playsNextAutomatically)
    }
}
