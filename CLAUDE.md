# Roadivo — app brief

Auto-loads whenever Claude works in `app/roadivo-app/`. The competitor review,
feature map, user flow, roadmap and name review are in `Docs/PRODUCT.md`.

## What this app is

An **iPhone-only** IPTV / M3U player for road trips. Users add their own M3U/M3U8
playlists (as a link, a file, pasted text or a QR code) and their own videos
(from Photos or Files). They watch on the phone, over AirPlay to a car display
or adapter, or in a landscape **Car Mode** for a dashboard mount.

It is for passengers, and for drivers who are parked, who already have an IPTV
subscription or their own videos. It competes with "CarTV - M3U IPTV Player &
Cast", with a more polished UI, an honest account of what works in the car, and
no ads or tracking. The name is *road* + *vivo* ("alive / live"), meaning live
TV on the road.

## First-launch flow & Pro

Onboarding (4 pages) → "Buy a plan" paywall (closable, shown once) → four
tabs: **Home · Favorites · Discover · Settings**.

- **Directions is kept for a later release** (owner, 2026-10-23; DECISIONS 149): `ROADIVO_DIRECTIONS = NO` in
  `Config/Shared.xcconfig` hides the tab and its route card everywhere, and nothing asks for Location. Don't use the
  map, Directions or CarPlay navigation anywhere until the owner switches them back on; the code stays.
  When on (`Features/Directions`, `Core/Directions`; DECISIONS 145, free): search a place (Apple Maps search),
  see the driving routes from the iPhone's location on a map, pick one, and hand off to Apple Maps for guidance.
  Location is asked the first time the tab opens. `DirectionsUITests` skip while it's off. UI tests use `ScriptedPlaceFinder` and `ScriptedLocation` (`-location-denied` for Location off).
  An open route follows to the other tabs as an upright window in the bottom-right corner, like Maps' own, above the
  mini player (`RouteMiniCard`, `RouteSnapshot`; DECISIONS 146).

- **Free:** 1 source, unlimited videos On this iPhone, AirPlay and PiP.
- **Pro:** unlimited sources and Car Mode, including Roadivo on CarPlay.
- StoreKit 2 runs through `StoreClient` (`StoreKitClient`; `FakeStoreClient` for
  tests and `-ui-testing`). Simulator runs use `StoreKit/Roadivo.storekit`.
- Product IDs are `com.disolutions.roadivo.pro.{weekly,yearly,lifetime}` and must match App Store Connect (DECISIONS 23).

## Discover and the car

- **Independent car browser prototype** (owner, 2026-10-23): Debug window builds with `ROADIVO_CAR_BROWSER = YES`
  open sites in `CarBrowserController`, never in the phone browser. It reuses `WebPageController` with isolated,
  nonpersistent website storage and mobile content preferences. `CarBrowserControls` provides template search,
  navigation, scrolling and ordinary-link selection. It requires Pro but no parking or Location evidence in Debug, per the owner's
  request (2026-10-23), and is hard-disabled in Release. Native video parking rules are unchanged. See `Docs/CarBrowserPrototype.md` for limitations and the required Mac/device checks.
  General webpage taps/forms and distribution approval are unverified; do not describe this as a complete browser.
  Browser shortcuts fill one row the car wraps across its width, each site's icon inset on Roadivo's surface colour as on the iPhone (light and dark) and 256 px icon requests. The More menu adds Start Page,
  Reload, Forward, up to six car-only tabs, session-only saved pages, page zoom and auto-hiding controls.
  YouTube has native search through `CarPlayBrowserTab.showSearch(on:)`; page links stay in native template lists.
  Direct webpage taps are unsupported by CPMapTemplate's base view; these actions do not establish general form input.
  The Debug input prototype installs `CarBrowserInputBridge` in car tabs only: trusted webpage field clicks open
  `CarBrowserFieldEditor`, then update the original field/frame through an isolated script world. More → Input test
  exposes a local form and input counters. This does not provide a new CarPlay tap-delivery API; require device proof.

- **Which CarPlay app the car shows** is `ROADIVO_CARPLAY_APP` in `Config/Shared.xcconfig` (one per app; DECISIONS 152):
  `window` (now), `media` or `map`. `CarPlayAvailability.app` reads it; `AppDelegate` and the Info.plist manifest pick
  the scene delegate, and the xcconfig picks the entitlements.
- **`window`, Roadivo's own CarPlay window** (owner, 2026-10-23; DECISIONS 152; `App/CarPlayWindowSceneDelegate.swift`,
  `CarPlayWindowController`, `Core/Car/CarWindowState.swift`). Signed with the navigation entitlement
  (`RoadivoNavigation.entitlements`) for its `CPWindow`, but no map is drawn: the window shows Roadivo's still road
  at the hour's light, as on the splash (`CarWindowCard`, `SplashMoment`; DECISIONS 158) or the chosen video. Home · Favorites · Library · Cast · Browser are a
  centered `CPTabBarTemplate` on the home screen (`CarPlayTabs`; DECISIONS 159), Home a plain list of recent picks; video,
  casting and the browser switch the root back to the window. Without the bar, `CPMapTemplate`'s four corner buttons
  (DECISIONS 157); Cast opens a CarPlay list whose empty view gives the steps (drawn by CarPlay, so the tap always shows). A row plays and
  the lists close. **Cast to the car** (`CarPlayMirror`, `ScreenMirrorReceiver`, `MJPEGParser`): the window reads the
  iPhone's Screen Broadcast over loopback and shows the whole iPhone while parked, with Home, End mirroring and Fit. While something plays only **Close** shows (it stops
  playback and the tabs return), with previous, play/pause and next as map buttons; the bar hides itself over video.
  **Video only while parked**: `ParkingMonitor` (`ParkingDetector`, `MotionSample`, `LocationMotionSampler`) counts the
  car parked after 30 s of still Core Location readings and unparks at the first moving or unknown one; or at once when
  the car stops limiting its keyboard (`CPSessionConfiguration`, the car's own word) with Location on and no moving
  reading (DECISIONS 153). Any moving reading ends video at once; moving shows
  "Video is off while driving. Sound keeps playing." and Location off asks for it on the iPhone. Never weaken this.
  Works in any car (no CarPlay video needed). Apple documents the window as map-only: the App Review notes say what it
  shows, and Apple may reject it or withdraw the entitlement; `media` is the fallback. The video has Car Mode's
  progress bar; a drag across it scrubs (`CarScrub`; CarPlay passes window touches only as pans) and the map buttons
  are ±15 s and play/pause (DECISIONS 154). Debug `-car-parked`, on in the scheme (`Project.swift`), sets
  `ParkingMonitor.assumesParkedCar` for desk testing; a moving GPS reading still ends video. Untick it to test parking.
- **The car and the iPhone keep their own videos** (owner, 2026-10-23; DECISIONS 155): `PlaybackController` records a
  `PlaybackOrigin` (`car` from the CarPlay apps). The iPhone's mini player shows only `phone` picks and its player
  closes when the car starts something; the CarPlay window plays only `car` picks. One player: the latest pick plays.
  The iPhone player has no Car Mode or AirPlay button any more.
- **`media`**: Roadivo's CarPlay template app (`App/CarPlaySceneDelegate.swift`) shows Favorites,
  Recent and Library, then hands playback to the shared player. A fourth **Browser** tab lists the Browser's
  sites; tapping one opens it in Discover › Browser on the iPhone, as CarPlay can't show web pages (DECISIONS 131).
  Now Playing has a ♥ for what's playing and Up Next for the rest of its group (DECISIONS 140); rows show each
  item's logo, still or video frame (`Core/Car/CarPlayArtwork.swift`, DECISIONS 141).
- **`media`: video on the car screen, under the Audio entitlement** (DECISIONS 139, 150). The App ID has CarPlay Audio,
  Navigation and Video enabled, but the app signs with **Audio only** (`Resources/Roadivo.entitlements`): Apple's
  iOS 27.2 guide says Audio and Video can't be held together and Audio covers apps that mix in video; Audio + Video
  left the car screen blank, and Video alone hid Roadivo (DECISIONS 133, 142). Navigation is kept for later (149).
  On iOS 27, in a car whose `CPSessionConfiguration.supportsVideoPlayback` is true, every playable row carries
  `CPPlaybackConfiguration(preferredPresentation: .video)` (`CarPlaySceneDelegate.playsAsVideo`): CarPlay shows the
  video while parked and Now Playing with sound while driving; the car decides, Roadivo never checks. Test with a
  real iPhone on USB: Device Hub › select the iPhone › Device › CarPlay Simulator › vehicle "Standard Video Playback".
- **`media`: Video-entitlement test builds** (owner, 2026-10-23; DECISIONS 151): `ROADIVO_CARPLAY_VIDEO` picks
  `Resources/RoadivoVideo.entitlements` (Video only). It's YES for Debug builds on an iPhone, NO for simulator builds
  and NO in `Config/Release.xcconfig`, so archives stay on Audio. Flip Release only after a Debug build shows video in
  the CarPlay Simulator; Video alone hides Roadivo in cars without CarPlay video. The trace logs `signed: Video/Audio`.
- **`map`, CarPlay Navigation: approved by Apple, kept for a later release** (owner, 2026-10-23; DECISIONS 147–149,
  152). `CarPlayNavigationSceneDelegate`: Roadivo's map, place search, route previews and turn-by-turn guidance
  (`CarPlayGuidance`, `RouteGuide`), signed with `RoadivoNavigation.entitlements`. Don't use it until the owner says.
- Video plays over AirPlay, parked only, in cars with CarPlay video. While
  driving, the car plays sound only.
- The **Discover** tab (`DiscoverView`, once "Cast to Car") has two cards (DECISIONS 118–124, 135–136; the Browser's card links its first four sites):
  **Browser** (`Features/Browser`, `Core/Browser`: full screen, a grid of sites with icons loaded at run time; nothing
  kept, no bookmarks or Recent; pages never open their apps; direct videos offer Play in Roadivo; its menu has only
  Start Page and Leave Browser) and **Cast to Screen** (`CastToScreenView`, as simple as CarTV's; DECISIONS 157: where
  the iPhone is and one Start/End mirroring button; the `RoadivoBroadcast` extension serves loopback only, for
  Roadivo's CarPlay window; End mirroring is `BroadcastSignal`; real iPhone only). Cast from an app was removed (owner, 2026-10-21). Car Mode has no
  button since DECISIONS 155: it opens when a saved car connects with Open Car Mode When Connected (owner to decide its
  way in). Car Mode shows a progress bar with large times, and Drive View hides the video for the driver (DECISIONS 114).
- The **CarPlay Browser tab** (`App/CarPlayBrowserTab.swift`, DECISIONS 134): on iOS 27 a search row (`CPSearchTemplate`,
  `BrowserSearch`: the address, matching sites, a web search), "Video on this page" when the iPhone's open page has a
  direct video (played on the car's screen as CarPlay video), then the sites. CarPlay can't show web pages, so sites and
  searches open in the iPhone's Browser (`AppEnvironment.browser`, `AppRouter.openInBrowser`).
- How to Connect (`Features/Shared/ConnectGuide*`, in Settings › Media and behind Cast to Screen) gives the user's steps; its CarPlay steps show
  only once CarPlay is switched on (DECISIONS 101).
- **Car & Display Profiles** (`Core/Display`, `Features/Shared/DisplayProfiles`; DECISIONS 110–113): This iPhone plus a profile per AirPlay receiver, CarPlay or wired display, with aspect ratio, Play Next Automatically, subtitles, preferred source and Open Car Mode When Connected (Pro). `CarConnection.receiver` picks the profile; `AppEnvironment` applies it to the player.
- CarPlay Audio was granted on 2026-10-20 and is on (`ROADIVO_CARPLAY = YES` in `Config/Shared.xcconfig`,
  DECISIONS 25, 127). Set to NO, the app hides every CarPlay promise (`CarPlayAvailability`, DECISIONS 84). Simulator builds carry
  the entitlements so Xcode's CarPlay window shows the app (DECISIONS 121). CarPlay Video was tried on
  2026-10-21 and dropped (DECISIONS 133, 139); the signing steps are in DECISIONS 127. Video views let go of the player in the
  background (`PlayerLayerView`, `SystemVideoPlayer.Coordinator`) so sound plays on with the iPhone locked.

## Design

Themeable. Settings › Theme picks the **appearance** (System, Light, Dark) and
an **accent** (Golden Hour is the default; also Sunset, Ocean, Twilight, Rose,
Graphite). `AppTheme.shared` holds the choice and both apply live
(DECISIONS 53–57).
- Never hard-code a brand colour. Use the tokens in `DesignSystem/Theme/Colors.swift`:
  `.roadAccent` (text-sized tint), `.roadBrand` / `.roadBrandGradient` (fills),
  `.roadOnBrand` (text on fills), `.roadCanvas` / `.roadSurface` (neutrals).
- Over an always-dark scene, set `.environment(\.colorScheme, .dark)` so
  `.roadAccent` resolves to its bright variant.
- A new accent goes in `ThemeAccent.palette`; `ThemeTests` enforces its WCAG
  contrast.
- Components: `PrimaryButton` (gradient + glow), `IconTile`, `EmptyStateView`,
  `SectionTitle`, `CardHeader`, `cardStyle()`.
- The code-drawn scenes (`RoadScene`, `CockpitView`) keep the road's yellow
  centre line and the logo's golden sun (`Palette.laneYellow`).
- Every screen shown in a tab (and every screen pushed there) adds `.clearsBottomAccessory()`, so the
  floating mini player never covers its content (DECISIONS 100).
- Type: Overpass by default; Settings › Theme › Font Style also offers Standard, Rounded and Serif. Use `Typography` tokens, never a hard-coded font (DECISIONS 93).

The tagline is "Let the Journey Play." (`Brand.tagline`). No green. See
DECISIONS 33, 37 and 53–57.

## Code style

- Comments are one or two lines at most, in every file (owner's rule, 2026-10-14). Keep the why, drop the rest.

## Localization

- English plus es, fr, de, it, pt-BR, ja, ko, zh-Hans, zh-Hant and hi
  (`Resources/Localizable.xcstrings` and `InfoPlist.xcstrings`).
- After changing UI text:
  1. Run `Scripts/sync-strings.sh .build/DerivedData` (after a test or build run
     into that path), or with no argument to build into a temp folder first.
  2. Translate the new keys.
  3. Run `python3 -I Scripts/merge-translations.py <lang>.json…`. It needs every
     key in each file and rebuilds `InfoPlist.xcstrings` from them, so for a few
     new keys add them to the catalog directly instead (DECISIONS 52). The
     command-line sync re-sorts the catalog; keep Xcode's order to avoid a
     whole-file diff.
- `StringCatalogTests` fails until every key is translated with matching
  format specifiers.
- Build each sentence as one string (no `Text + Text` fragments) so
  translators can reorder it.
- In code, use `String(appLocalized:)` (never `String(localized:)`) and
  `Text(app: resource)` for stored `LocalizedStringResource`s. These follow
  the in-app language choice live (`AppLanguage`, DECISIONS 40).

## Domain / data model

- **Playlist** (SwiftData):
  - `kind` is `remote` (a link that can be refreshed), `file` (imported once or pasted) or `localVideos` (the single "On this iPhone" playlist).
  - `sourceHost` is safe to show in the UI.
  - The **full link lives in the Keychain** under `playlist.source.<id>`. Provider links usually embed a username and password.
- **Channel** (SwiftData):
  - Fields: name, `group` (from `group-title`), logo URL, stream URL, `sortIndex` (file order), `isFavorite`, `lastPlayedAt`.
  - Watch history: `resumePosition` (where the next play starts), `duration`, `finishedAt` (watched to the end). Rules in `PlaybackProgress`.
  - An imported video is stored as `roadivo-local:<file name>`, never as an absolute path.
- **MediaItem**: a value snapshot of a Channel. Views and the player only see this.
- **M3UParser**: a tolerant extended-M3U parser. It handles a BOM, CRLF, a missing header, quoted commas, `#EXTGRP`, `tvg-name` and relative URLs, and skips junk lines.

## Business rules

- **No bundled content, ever.**
  - Release builds ship zero channels.
  - `DemoLibrary` uses Apple's public HLS test streams and exists in DEBUG builds only, for UI tests and screenshots.
- **Single HLS stream:** a link to one HLS stream (`#EXT-X-STREAM-INF` or `#EXT-X-TARGETDURATION`) becomes a one-item playlist.
- **Pasted M3U text** is added directly, with no download.
- **Refreshing a source** keeps favourites and watch history for every stream still present: by link, or by title, group and year when the link changed (a new token or server address; DECISIONS 107).
- **Next / previous** step through the item's own group.
- **Up next:** when a video ends (with Play Next Automatically on), a 5 s countdown with Play Now and Cancel comes before the next one; playing, pausing, seeking, stopping, voice search, a call, deleting the next video or a screen set not to play on cancels it, and in the background the next starts at once (`PlaybackController+UpNext`, `UpNextCountdownView`, DECISIONS 115–116).
- **Continue Watching** shows the 12 most recently played items not yet watched to the end (DECISIONS 104–107):
  - Films and episodes of 5 minutes or more resume where they stopped (`PlaybackController` keeps the place every 10 s through `LibraryRepository+History`); from 90 % they count as watched.
  - Every card shows a progress bar and the time left; the row's card menu adds Play from Beginning and Remove from Continue Watching.
  - A row mixing posters with wide cards draws every card 16:9, the poster cropped to fill it (DECISIONS 108).
- **Deleting "On this iPhone"** also deletes the copied video files.
- **Media servers:** Jellyfin, Emby and Xtream sign in with an address and login; Plex with a code at plex.tv/link (`PlexClient`, `PlexLoginViewModel`, DECISIONS 72).
- **Browsing:** group chips (one group at a time, no "All") in the player, on a group's screen and on a source's screen (Manage Sources › a source: Refresh, Rename, Copy Link, Delete). Home's one button is + until a source exists, then the source menu (DECISIONS 95–96).
- **Source Health:** Manage Sources › a source › More › Source Health (`SourceHealthViewModel`, `StreamChecker` in `Core/Health`): refresh outcome, unreadable entries, and a user-started stream check, two streams at a time; media servers check the server only; On this iPhone has none (DECISIONS 103, 109). UI tests use `ScriptedStreamProbe`.
- **Server artwork:** media-server films are 2:3 posters with their year; episodes are 16:9 stills (`ArtworkStyle`, DECISIONS 97).
- **Voice search:** the mic in Home's search bar (`SearchField`, `VoiceSearchModel`, `Core/Speech`) fills the search as you speak; on-device when the language allows (DECISIONS 68–69).

## Backend / API

None in v1 (DECISIONS 6). Everything is stored on the device.
- `Core/Networking/APIClient` is the seam for a future service. It reads `API_BASE_URL` from `Config/*.xcconfig` (placeholder `https://api.example.com`). Nothing calls it yet.
- Playlists are fetched directly from the user's provider by `URLSessionPlaylistFetcher`.

## Constraints & non-goals

- **Device:** iPhone only, iOS 17+, portrait and landscape.
- **CarPlay:** Roadivo's own window (navigation entitlement, no map) with the four tabs as buttons and video only
  while parked (DECISIONS 152); the CarPlay Audio template app is the fallback (`ROADIVO_CARPLAY_APP = media`, DECISIONS
  139, 150). The navigation map is approved by Apple but kept for a later release (DECISIONS 147–149).
- **Not in v1:**
  - EPG
  - MKV, raw TS and AC3
  - starting AirPlay Screen Mirroring from the app (Apple has no API; Screen Broadcast covers browser screens)
  - Arabic and other right-to-left languages
- **ATS:** `NSAllowsArbitraryLoads` is on (DECISIONS 8). Justify it in the App Review notes.
- **Privacy:** no tracking, no ATT prompt, no third-party SDKs.
- **Legal page:** `Docs/Website/roadivo.html` is one self-contained file (privacy,
  terms, support). It is hosted for App Store Connect, and the app shows the same
  file at Settings › Privacy Policy. Edit it directly; it is English only (DECISIONS 81).
- **Before release:** host `Docs/Website/roadivo.html` for the App Store's Privacy Policy and Support URLs.
- **Uploads:** builds 1 and 2 of 1.0.0 are on TestFlight; the next upload is build 3. Raise `buildNumber` in `Project.swift` by one for every upload
  (App Store Connect refuses a number it has seen), keep `marketingVersion` until 1.0.0 is released, run
  `tuist generate`, and archive with the `Roadivo` scheme (DECISIONS 126).

## Commands

Xcode 26.4 or later builds CarPlay's video rows (their APIs need Swift 6.3); Xcode 26.2 and 26.3 still build Roadivo, without them.
Xcode 27 needs macOS 26.6 or later.

```bash
tuist generate --no-open
# If ~/.cache is root-owned on a Mac, Tuist crashes: prefix the line above with
# XDG_CACHE_HOME=$TMPDIR/tuist-cache.

# Build output goes to .build/DerivedData (gitignored). Never into Derived/:
# that folder holds Tuist's generated sources, which are committed.
# Use any installed iPhone simulator (`xcrun simctl list devices available`).
xcodebuild -workspace Roadivo.xcworkspace -scheme Roadivo \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath .build/DerivedData test
swiftlint --strict && swiftformat .
swift Scripts/generate-app-icon.swift   # redraws AppIcon (car) and AppIcon-Classic, light/dark/tinted
Scripts/export-review-screenshots.sh "iPhone 16e"   # re-runs the UI tests and refreshes Screenshots/review
```

UI tests launch the app with these arguments:
- `-ui-testing`: memory-only store, Keychain and defaults, fake App Store
- `-pro`: the fake store starts with Pro
- `-skip-onboarding`
- `-demo-library`
- `-demo-history`: with `-demo-library`, a film part-watched and a channel played
- `-voice-phrase <text>`: what the scripted microphone hears (default "Football")
