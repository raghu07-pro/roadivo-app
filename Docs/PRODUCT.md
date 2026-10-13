# Roadivo: product review and plan

**Reference app:** CarTV - M3U IPTV Player & Cast (Lyntra Technology Ltd, App Store id6800211040).
**Reviewed:** 2026-10-12, using its App Store listing and the owner's 26 screenshots.

## 1. CarTV at a glance

- **Pitch:** "a lightweight M3U / M3U8 playlist tool, built for watching on the road". Subtitle: "Camp movies on the car display".
- **Store standing:**
  - Utilities category, #30 among free apps.
  - Rated 4.5★ from 3.9K ratings.
  - Requires iOS 18+.
  - Available in 22 languages.
- **Pricing:**
  - weekly $3.99 (₹80, with a ₹20 first week)
  - yearly $45.99
  - lifetime $21.49 (marked "Most popular")
- **Privacy:**
  - It shows the App Tracking Transparency prompt and uses Adjust and Meta for ad attribution.
  - The policy says playlists stay on the device.
  - There are no accounts.

| Area | What CarTV does |
|---|---|
| Onboarding | Four photo pages: "Meet the all-new CarTV", "Their favorites, on the big screen", "Charging stops become movie time", "Bring in your own videos". Then the paywall, then the ATT prompt. |
| Sources | Paste a link or a whole config, or scan a QR code with the camera or from a photo. Also connects to Jellyfin, Emby, Plex and Xtream. Bad input shows "No usable link found" inline. A "Get Help" link and a rights disclaimer sit below. |
| Home | Grouped channels plus "Search channels and titles" with a voice search button. |
| Favorites | Two segments: Favorites (long-press to save) and Local (import from Photos, video files or a folder). |
| Cast to Car | Whole-screen mirroring "from any app". Until connected it shows "CarPlay not connected". |
| Player | HLS and HTTP streams, hardware decoding with a software fallback, subtitles (embedded, external, MKV), a mini player, a landscape Car Mode, and support for rotary knobs. |
| Settings | Pro, Manage Sources, Language (22), Privacy, Terms (EULA), Help & FAQ (accordion), Version. |

**Where CarTV is weak (our openings):**
- **The car promise is misleading.** It talks about "CarPlay", but third-party apps can't show video in CarPlay. Video only reaches the car screen through AirPlay-capable cars or adapters. Reviews mention audio/video lag.
- **It looks generic.** Tiles are grey stock boxes.
- **No continuity.** There is no "continue watching" row and no up-next list.
- **Monetisation comes first.** The paywall and ads appear before the user has played anything, and there is tracking.
- **Dead-end empty states.**

## 2. Roadivo vs CarTV

| CarTV | Roadivo (built) |
|---|---|
| Grey tiles | Every item gets art: its logo, or a gradient with its initials |
| Flat groups | **Continue Watching** row, then a carousel per group, with **See All** grids |
| Basic player | **More in <group>** up-next list, favourite heart, AirPlay, Picture in Picture, and channel switching from lock-screen and steering-wheel buttons |
| Mini player | Floating mini player with a **live video thumbnail** on every tab |
| "CarPlay not connected" | **Car tab** that tells the truth: AirPlay in one tap, Car Mode (landscape, giant controls, screen kept awake), a 3-step setup guide and a safety note |
| Paste box | Paste a **link or the M3U text itself**, **scan a QR code**, inline "No usable link found", and a rights disclaimer |
| Local tab | **On this iPhone**: import from **Photos** or **Files**, plays offline |
| Ads + ATT tracking | **No ads, no tracking, no account**. Playlist links are stored in the **Keychain**. |
| Light only | Warm "night drive" palette that works in light and dark, Dynamic Type, VoiceOver, Reduce Motion |

## 3. Roadivo's flow

1. **Onboarding** (4 pages, can be skipped): Meet Roadivo → Their favorites, on the big screen → Charging stops become movie time → Bring your own playlists.
2. **Home** (empty at first) → **Add a Source** sheet with three options: Link or M3U, M3U File, or Videos.
3. **Home** shows Continue Watching, the group carousels and search.
4. **Player** → **minimise** to the mini player, or switch to **Car Mode**.
5. **Favorites** tab: Favorites, plus On this iPhone (import from Photos or Files).
6. **Car** tab: Start Car Mode (resumes the last thing watched), the AirPlay picker and the setup guide.
7. **Settings** tab: Manage Sources (refresh, rename, delete), Add a Source, Help & FAQ, Privacy, Terms, Version.

## 4. Roadmap

Not in v1, in priority order:
1. **StoreKit 2 paywall:** lifetime and yearly. Show it after the first successful playback. Needs the owner's go-ahead and App Store Connect products.
2. **Xtream Codes login:** builds the M3U link from server, username and password.
3. **XMLTV EPG:** now/next listings.
4. **Jellyfin, then Emby, then Plex.**
5. **Fallback engine** (KSPlayer or VLCKit) for MKV, raw TS and AC3, only if needed.
6. **Localisation** into the top 10 store languages, plus a Language row in Settings.
7. **ReplayKit screen mirroring.**
8. **Rotary-knob and keyboard focus** in Car Mode.

## 5. Name review (owner's candidates, checked 2026-10-12)

| Name | Meaning | App Store (search API) | Web / other | Verdict |
|---|---|---|---|---|
| **Roadivo** | road + *vivo* (Latin, Italian, Spanish, Portuguese: "alive / live") → "live on the road" | no apps | No brand found ("Roadio" dashcam and "Roadly" are only similar-sounding). roadivo.com is registered. | ✅ **Chosen** |
| Dashora | dash(board) + *-ora* | no apps | No brand found. dashora.com is registered. | Good backup |
| Cruvanta | cruise + *avanti* ("forward") | no apps | No brand found | OK, harder to say and spell |
| Moventra | move / movie + entertainment | no apps | "Movent" and "Moventur" (a car-rental app) are close | Confusion risk |
| Drivora | drive + *-ora* | **1 app** ("Drivora: AI Car Photo & Video") | Drivora LTD, an Android game studio | ❌ Taken |
| Velmora | no car or video meaning | **4 apps** ("Velmora AI", "Velmora: Soulmate Drawing", …) | — | ❌ Taken |

Before launch:
- Run trademark searches at USPTO, WIPO and EUIPO in classes 9 and 41.
- Secure a domain (roadivo.app or getroadivo.com).
- Suggested App Store title (30 characters max): **"Roadivo: M3U & IPTV Player"**.

## 6. Parity with CarTV (2026-10-13)

| CarTV screen | Roadivo |
|---|---|
| 4 onboarding pages | ✅ Illustrated road scenes from golden hour to night |
| Paywall (weekly, yearly, lifetime) → close | ✅ Same plans, lifetime preselected, closable, Restore, renewal terms |
| ATT tracking prompt | ✗ On purpose: Roadivo doesn't track |
| Home: search plus grouped channels | ✅ Plus a road-scene hero, Continue Watching and highway-sign groups |
| Favorites: Favorites / Local, import from Photos, video files or a folder | ✅ |
| Cast to Car | ✅ Roadivo's own CarPlay app (needs Apple's entitlement), AirPlay and Car Mode, with live status |
| Add a Source: paste link or config, QR from camera or photo, inline "No usable link found", Jellyfin / Emby / Xtream, Get Help | ✅ Plex not yet |
| Settings: Pro, Manage Sources, Language, Privacy, Terms, Help & FAQ, Version | ✅ |
| Real-time subtitles, rotary-knob support | Roadmap |
