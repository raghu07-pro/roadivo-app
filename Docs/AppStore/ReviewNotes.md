# App Review notes — Roadivo 1.0

Paste the text below into App Store Connect › App Review Information › Notes (it is under the
4,000-character limit). No sign-in is needed, so leave the demo account fields empty.

---

Roadivo is a player for media the user already has. It ships with no channels, playlists or video and
is not affiliated with any TV provider. Users add their own M3U/M3U8 playlist (link, file, pasted text
or QR code), sign in to their own Jellyfin, Emby, Plex or Xtream server, or import videos from Photos
or Files.

HOW TO TEST WITH SAMPLE CONTENT (Apple's public HLS test streams)
1. Finish onboarding. Close the "Buy a plan" screen with its Close (X) button.
2. On Home, tap + to open "Add a Source". Keep "Playlist", paste this text, then tap Add Source:

#EXTM3U
#EXTINF:-1 group-title="Samples",Apple Sample 1
https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8
#EXTINF:-1 group-title="Samples",Apple Sample 2
https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8

3. Tap a sample to play it: favourites, next/previous within the group, Picture in Picture when you
   leave the app, and "Up next in 5" when a video ends. "Media servers" signs in to a server instead.

IN-APP PURCHASES (Roadivo Pro)
- Free: one source, unlimited imported videos, AirPlay and Picture in Picture.
- Pro (Weekly or Yearly auto-renewable subscription, or Lifetime one-time purchase): unlimited
  sources, Car Mode and CarPlay.
- Plans show after onboarding, on a second source and in Settings › Roadivo Pro, with price, period,
  first-week offer, renewal terms, Terms of Use (Apple's standard EULA), Privacy Policy and Restore.

CAR MODE AND CARPLAY (Pro)
Car Mode (large landscape controls for a dashboard mount) opens when a saved car connects with
Settings › Car & Display Profiles › Open Car Mode When Connected on.
On CarPlay, Roadivo uses the navigation entitlement for its window but draws no map. Home, Favorites,
Library, Cast and Browser are CarPlay template tabs. A chosen item plays; while the car is parked the
window shows its video, and Close stops it. Cast shows the iPhone's own screen there while parked.
Parked means CarPlay stops limiting its keyboard, or Core Location reports the car still for 30 seconds;
any movement turns the picture off at once, leaving the sound. Play on iPhone / Play on Car Display move
a video between the two. No web page is ever shown on the car's screen:
a site picked there opens in the Browser on the iPhone. Test it in the CarPlay Simulator after buying Pro
in the sandbox.

DISCOVER TAB
- Browser: a general web browser whose start page links to popular video websites (opened as websites,
  never their apps). Roadivo provides no content. Page videos play in the page; a direct video link can
  play in Roadivo's player.
- Cast to Screen: Start mirroring opens Apple's broadcast sheet with Roadivo's Broadcast Upload
  Extension. With Roadivo open on CarPlay and the car parked, the car's screen shows the iPhone's screen;
  frames stay on the device (loopback only), nothing is recorded or uploaded. Needs a real iPhone.

MAPS TAB
Search a place to see the driving routes from the iPhone's location on Apple's map, on the iPhone or the car.

PERMISSIONS (each asked only when the feature is used)
- Camera: scanning a playlist's QR code.
- Microphone and Speech Recognition: voice search on Home.
- Local Network: media servers or playlists on the home network.
- Location (While Using): routes in Maps, and on CarPlay to tell when the car is parked. Not stored.

APP TRANSPORT SECURITY
NSAllowsArbitraryLoads is set because users' playlists and servers are often plain http on hosts we
cannot list in advance, including home servers.
NSAllowsArbitraryLoadsForMedia would not cover the playlist download or the Jellyfin, Emby, Plex and
Xtream APIs, which use URLSession. Roadivo connects only to addresses the user enters, Apple's App Store
lookup for update notices and plex.tv for Plex sign-in.

PRIVACY
No account, ads, analytics, third-party SDKs or tracking. Playlists, logins (Keychain) and history stay
on the device.
