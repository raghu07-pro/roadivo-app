# Independent car browser prototype

The window CarPlay app now has its own mobile-content WKWebView. Site shortcuts and search open full webpages in that view, without using AppEnvironment.browser or navigating the phone. Its cookies and website storage are held in a separate, nonpersistent store for the life of the car browser controller. Phone browsing keeps its existing storage and behavior.

This is an experiment, enabled by ROADIVO_CAR_BROWSER in Debug and hard-disabled outside DEBUG. It uses the existing navigation-entitled CPWindow. Apple documents that window for maps; rendering a webpage there does not establish distribution approval or complete browser input support. The media-template app retains its existing behavior.

## Build on a Mac

New source and test files are included by Project.swift's source globs. Regenerate the Xcode project first; the committed generated project has deliberately not been hand-edited.

```bash
tuist generate --no-open
xcodebuild -workspace Roadivo.xcworkspace -scheme Roadivo \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath .build/DerivedData test
swiftlint --strict
swiftformat . --lint
```

Use an installed simulator name. For actual CarPlay testing use a signed Debug build on an iPhone with ROADIVO_CARPLAY_APP = window. This branch does not change the entitlement files. A simulator result is not evidence that the real car accepts the view or forwards webpage input.

## Controls and behavior

- Open Browser, then a site or Search or enter website. The page stays in the car window.
- Top buttons: Back, Forward, Search, Close. Empty search offers the site shortcuts again.
- Side buttons: scroll up, scroll down, and links. Links lists ordinary HTTP/HTTPS anchors from the current document, plus Reload and More links when necessary. A link opens the full destination in the same car browser.
- Map pans scroll the document instead of seeking the video while the browser is open.
- The Debug car browser requires Pro but does not depend on parked status or Location readings. It stays available with missing, unknown, moving, denied, or stale readings, including in the CarPlay simulator. The browser remains hard-disabled outside DEBUG; native video parking rules are unchanged.
- Close and disconnect stop loading, suspend media, and drop the document. Starting a library video closes the car browser. Opening the car browser stops only native playback whose origin is car.
- Car browser telephone/mail links never launch an app on the phone.

## Required device checks

1. Open an article from a typed URL and from a web search. Confirm the full document renders with mobile content preferences, including content below the fold. Layout can differ with display dimensions.
2. Follow links using the native link list; test Back, Forward, Reload, pagination, and map-pan/arrow scrolling on touchscreen and rotary-only cars.
3. Open a different URL on the phone. Confirm neither browser changes the other's page or history. Sign in to a test site and verify sessions are isolated.
4. In the simulator or a stationary test setup, try unknown location, permission denial, old readings, and a silent location stream. Confirm the Debug browser stays available. Verify Pro loss still blocks the page and suspends its media.
5. Test page failures, redirects, target=_blank links, a renderer process termination, reconnect, phone lock/unlock, and Pro access changes.
6. Test direct taps, HTML buttons, forms, embedded frames, media, and site logins separately. These are NOT established by adding a WKWebView. CarPlay normally forwards map gestures rather than general-purpose web input. The template link list does not supply arbitrary form entry, iframe navigation, or trusted DOM clicks. Protected media and downloads are not promised.
7. Archive Release and verify the experimental browser cannot be enabled by plist settings or launch arguments.

## Validation in the coding environment

Linux cannot run Xcode, Tuist generation, SwiftLint, or the iOS tests here. Added Swift tests cover independent browser ownership/storage, queued-navigation cancellation, safe link selection, and Debug-only Pro access. These tests require execution on a Mac. This prototype must remain a draft until build, input, lifecycle, and distribution feasibility are verified.
