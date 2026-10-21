# App Review notes — Roadivo 1.0

Paste the text below into App Store Connect › App Review Information › Notes (it is under the
4,000-character limit). No sign-in is needed, so leave the demo account fields empty.

---

Roadivo is a player for media the user already has. It ships with no channels, playlists or video, and
it is not affiliated with any TV provider. Users add their own M3U/M3U8 playlist (a link, a file,
pasted text or a QR code), sign in to their own Jellyfin, Emby, Plex or Xtream server, or import videos
from Photos or Files.

HOW TO TEST WITH SAMPLE CONTENT (Apple's public HLS test streams)
1. Finish onboarding. Close the "Buy a plan" screen with its Close (X) button.
2. On Home, tap + to open "Add a Source". Paste this text into the box, then tap Add Source:

#EXTM3U
#EXTINF:-1 group-title="Samples",Apple Sample 1
https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8
#EXTINF:-1 group-title="Samples",Apple Sample 2
https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8

3. Tap a sample to play it. The player has favourites and next/previous within the group, and
   continues in Picture in Picture when you leave the app. When a video ends, "Up next in 5" offers Play Now or Cancel.

The same box also accepts a single stream link, such as the first URL above.

IN-APP PURCHASES (Roadivo Pro)
- Free: one source, unlimited imported videos, AirPlay and Picture in Picture.
- Pro (Weekly or Yearly auto-renewable subscription, or Lifetime one-time purchase): unlimited
  sources and Car Mode.
- The plans appear after onboarding, when adding a second source, from the car button in the player,
  and in Settings › Roadivo Pro. The paywall shows each plan's price and period, the first-week offer,
  the renewal terms, Terms of Use (Apple's standard EULA), Privacy Policy and Restore.

CAR MODE AND CARPLAY (Pro)
Play any video, then tap the car button in the player: Car Mode shows large landscape controls for
a phone on a dashboard mount, and "Drive View" hides the video for the driver. Roadivo is
also a CarPlay audio app (CarPlay Audio entitlement only): Favorites, Recent and Library lists, and Now
Playing with a favourite button and Up Next. Where the car offers video to the app, a chosen item plays as
video over AirPlay while the car allows it (parked); otherwise CarPlay shows Now Playing with sound only.
Roadivo never asks whether the car is parked; the car decides. Test it in the CarPlay Simulator after
buying Pro in the sandbox.

DISCOVER TAB › BROWSER, CAST TO SCREEN
- Browser: a general web browser. Its start page links to popular video websites (opened as websites,
  never their apps; their icons load from the sites). Roadivo provides no content. A page's videos play
  in the page, with its own AirPlay button; a direct video link can play in Roadivo's player instead.
- Cast to Screen: Start Broadcast opens Apple's broadcast sheet with Roadivo's Broadcast Upload
  Extension, which shows the screen (JPEG frames) to a web browser on the same Wi-Fi, at the
  http://...:8080/<code> address shown. Nothing is recorded or uploaded. To test: a real iPhone and any
  computer's browser. Below it, steps for iOS's own Screen Mirroring.
- On CarPlay, a Browser tab lists the same sites and (iOS 27) a search field. No web page is ever shown on
  the car's screen: a site or search opens in the Browser on the iPhone, and a direct video found on the
  iPhone's open page can be played through Roadivo's player (as video where the car allows it).

PERMISSIONS (each asked only when the feature is used)
- Camera: scanning a QR code that contains a playlist link.
- Microphone and Speech Recognition: voice search on Home.
- Local Network: reaching a media server or playlist on the user's home network; Screen Broadcast.
- Location (While Using): only in the Directions tab, as the start of a route to a searched place. It's asked the
  first time Directions opens, never stored, and sent nowhere but Apple Maps' own routing. Guidance opens in Apple Maps.

APP TRANSPORT SECURITY
NSAllowsArbitraryLoads is set because users play their own playlists and servers, and these are often
plain http on hosts we cannot list in advance, including servers on a home network
(e.g. http://192.168.1.10:8096). NSAllowsArbitraryLoadsForMedia alone would not cover the playlist
download or the Jellyfin, Emby, Plex and Xtream APIs, which use URLSession. Roadivo has no http
endpoints of its own. It connects only to addresses the user enters, plus Apple's App Store lookup for
update notices and plex.tv for Plex sign-in.

PRIVACY
No account, no ads, no analytics or third-party SDKs, no tracking. Playlists, logins (in the Keychain)
and watch history stay on the device.
