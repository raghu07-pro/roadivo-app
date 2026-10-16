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
tabs: **Home · Favorites · Cast to Car · Settings**.

- **Free:** 1 source, unlimited videos On this iPhone, AirPlay and PiP.
- **Pro:** unlimited sources and Car Mode, including Roadivo on CarPlay.
- StoreKit 2 runs through `StoreClient` (`StoreKitClient`; `FakeStoreClient` for
  tests and `-ui-testing`). Simulator runs use `StoreKit/Roadivo.storekit`.
- Prices and product IDs are placeholders (DECISIONS 23).

## Cast to Car

- Roadivo's CarPlay app (`App/CarPlaySceneDelegate.swift`) shows Favorites,
  Recent and Library, then hands playback to the shared player.
- Video plays over AirPlay, parked only, in cars with CarPlay video. While
  driving, the car plays sound only.
- The tab shows live CarPlay and AirPlay status (`CarConnection`). Until a car is connected it only
  explains how to connect; Car Mode and AirPlay appear once connected (DECISIONS 98). Car Mode is
  always one tap away from the player's car button (DECISIONS 102). Car Mode shows a progress bar with large times, and Drive View hides the video for the driver (DECISIONS 114).
- How to Connect (`Features/Shared/ConnectGuide*`, in Cast to Car and Settings › Media) gives the user's steps; its CarPlay steps show
  only once CarPlay is switched on (DECISIONS 101).
- **Car & Display Profiles** (`Core/Display`, `Features/Shared/DisplayProfiles`; DECISIONS 110–113): This iPhone plus a profile per AirPlay receiver, CarPlay or wired display, with aspect ratio, Play Next Automatically, subtitles, preferred source and Open Car Mode When Connected (Pro). `CarConnection.receiver` picks the profile; `AppEnvironment` applies it to the player.
- CarPlay needs Apple's entitlements; it is switched off until they are
  granted (`ROADIVO_CARPLAY` in `Config/Shared.xcconfig`, DECISIONS 25). While
  it is off, the app hides every CarPlay promise (`CarPlayAvailability`, DECISIONS 84).

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
- **Up next:** when a video ends (with Play Next Automatically on), a 5 s countdown with Play Now and Cancel comes before the next one; playing, pausing, seeking or stopping cancels it, and in the background the next starts at once (`PlaybackController+UpNext`, `UpNextCountdownView`, DECISIONS 115).
- **Continue Watching** shows the 12 most recently played items not yet watched to the end (DECISIONS 104–107):
  - Films and episodes of 5 minutes or more resume where they stopped (`PlaybackController` keeps the place every 10 s through `LibraryRepository+History`); from 90 % they count as watched.
  - Every card shows a progress bar and the time left; the row's card menu adds Play from Beginning and Remove from Continue Watching.
  - A row mixing posters with wide cards draws every card 16:9, the poster cropped to fill it (DECISIONS 108).
- **Start Car Mode** on the Car tab resumes the last-played item when nothing is playing.
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
- **CarPlay:** a CarPlay video and audio app, gated on Apple's entitlements (DECISIONS 25).
- **Not in v1:**
  - EPG
  - MKV, raw TS and AC3
  - screen mirroring
  - Arabic and other right-to-left languages
- **ATS:** `NSAllowsArbitraryLoads` is on (DECISIONS 8). Justify it in the App Review notes.
- **Privacy:** no tracking, no ATT prompt, no third-party SDKs.
- **Legal page:** `Docs/Website/roadivo.html` is one self-contained file (privacy,
  terms, support). It is hosted for App Store Connect, and the app shows the same
  file at Settings › Privacy Policy. Edit it directly; it is English only (DECISIONS 81).
- **Before release:** set `APP_STORE_ID` in `Config/Shared.xcconfig` (Settings › Rate and Share Roadivo; DECISIONS 64),
  and host `Docs/Website/roadivo.html` for the App Store's Privacy Policy and Support URLs.

## Commands

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
