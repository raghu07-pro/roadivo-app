# Independent car browser prototype

The window CarPlay app now has its own WKWebView, loading desktop sites as CarTV does (DECISIONS 162). Site shortcuts and search open full webpages in that view, without using AppEnvironment.browser or navigating the phone. Its cookies and website storage are held in a separate, nonpersistent store for the life of the car browser controller. Phone browsing keeps its existing storage and behavior.

This is an experiment, enabled by PLAYCARTV_CAR_BROWSER in Debug and hard-disabled outside DEBUG. It uses the existing navigation-entitled CPWindow. Apple documents that window for maps; rendering a webpage there does not establish distribution approval or complete browser input support. The media-template app retains its existing behavior.

## Build on a Mac

New source and test files are included by Project.swift's source globs. Regenerate the Xcode project first; the committed generated project has deliberately not been hand-edited.

```bash
tuist generate --no-open
xcodebuild -workspace PlayCarTV.xcworkspace -scheme PlayCarTV \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath .build/DerivedData test
swiftlint --strict
swiftformat . --lint
```

Use an installed simulator name. For actual CarPlay testing use a signed Debug build on an iPhone with PLAYCARTV_CARPLAY_APP = window. This branch does not change the entitlement files. A simulator result is not evidence that the real car accepts the view or forwards webpage input.

## Controls and behavior

- Open Browser, then a site or Search or enter website. The page stays in the car window.
- Top buttons: Close, Back, Search and More, with consistent symbol weights and sizes. Empty search offers shortcuts.
- More opens Start Page, Forward, Reload, Tabs, Saved pages, Page size, Links on this page and Hide browser controls.
  CarPlay draws these native controls; this is not a pixel-for-pixel copy of a custom browser toolbar.
- Shortcuts use four columns, rounded artwork with consistent padding, individual letter placeholders and shorter
  car labels. Icons request 256 px images and use a new cache so older low-resolution files are fetched again.
- Tabs are limited to six, retain separate documents and zoom, and share only the car's nonpersistent cookie store.
  Switching tabs suspends the previous tab's media. Closing the last tab leaves a new empty tab.
- Saved pages are session-only. Close or disconnect clears tabs, saved pages and car cookies; phone data is untouched.
- Page size offers 75–175% webpage zoom, not a universal text-only resize. Hide browser controls enables CarPlay's
  automatic navigation-bar hiding; the side restore button remains available. This does not force video full screen.
- On a YouTube page, More → Search YouTube opens native CarPlay text entry. Choose the YouTube result to load
  youtube.com/results with an encoded search query. Then use Links on this page to select ordinary result links.
  This avoids YouTube's inaccessible inline search field; it does not add direct website taps or microphone access.
- Side buttons: scroll up, scroll down, and links. Links lists ordinary HTTP/HTTPS anchors from the current document, plus Reload and More links when necessary. A link opens the full destination in the same car browser.
- Map pans scroll the document instead of seeking the video while the browser is open.
- The Debug car browser requires Pro but does not depend on parked status or Location readings. It stays available with missing, unknown, moving, denied, or stale readings, including in the CarPlay simulator. The browser remains hard-disabled outside DEBUG; native video parking rules are unchanged.
- Close and disconnect stop loading, suspend media, and drop the document. Starting a library video closes the car browser. Opening the car browser stops only native playback whose origin is car.
- Car browser telephone/mail links never launch an app on the phone.

## Plain CarPlay window with direct taps (DECISIONS 161–163)

Debug iPhone builds (`PLAYCARTV_CARPLAY_APP = screen` in `Config/Debug.xcconfig`) give the car a plain window under
CarPlay's undocumented `UIWindowSceneSessionRoleCarPlay` role, as the open-source Cafari Lite does
(github.com/rPlayAI/cafari-lite). They sign with CarPlay Audio + Video (`Resources/PlayCarTVCarScreen.entitlements`),
and the `carScreenScene` build script puts the role into the built Info.plist. In that window the car's taps reach
PlayCarTV's views and the webpage directly:

- `CarScreenController` draws the whole car app: Home, Favorites, Library, Cast and Browser along the top, playback
  and Cast controls, and the browser.
- The browser shows pages at 75% under a bar along the top, as in CarTV: Close, Back, Forward, the page's address
  (tap to search), Reload and Full screen. Full screen leaves one button in the corner to bring the bar back.
- Any tapped text box opens `CarSearchPage`, with PlayCarTV's keyboard: text, search, address, email, phone,
  password and number fields, text areas and rich editors, including through a field's label. Passwords show as dots
  and never come back from the page; number fields open on the numbers. A tapped dropdown opens `CarChoicesPage`.

Verified in the CarPlay Simulator with an iPhone 11 Pro on iOS 27.0.1. The role isn't in Apple's public headers,
App Review may reject it, and Cafari and CarTV both report the iOS 27.2 beta breaking it. Delete the two
`PLAYCARTV_CARPLAY_APP` lines in `Config/Debug.xcconfig` to bring back the template window and its tabs.

## Required device checks

1. Open an article from a typed URL and from a web search. Confirm the full document renders with mobile content preferences, including content below the fold. Layout can differ with display dimensions.
2. Follow links using the native link list; test Back, Forward, Reload, pagination, and map-pan/arrow scrolling on touchscreen and rotary-only cars. Test all new More actions, six-tab limit, tab switching, save/remove page, zoom, and the restore-controls button. Check labels and artwork in light/dark appearances and small displays.
3. Open a different URL on the phone. Confirm neither browser changes the other's page or history. Sign in to a test site and verify sessions are isolated.
4. In the simulator or a stationary test setup, try unknown location, permission denial, old readings, and a silent location stream. Confirm the Debug browser stays available. Verify Pro loss still blocks the page and suspends its media.
5. Test page failures, redirects, target=_blank links, a renderer process termination, reconnect, phone lock/unlock, and Pro access changes.
6. Test direct taps, HTML buttons, forms, embedded frames, media, and site logins separately. These are NOT established by adding a WKWebView. CarPlay normally forwards map gestures rather than general-purpose web input. The template link list does not supply arbitrary form entry, iframe navigation, or trusted DOM clicks. Protected media and downloads are not promised.
7. Archive Release and verify the experimental browser cannot be enabled by plist settings or launch arguments.
8. On YouTube, use More → Search YouTube with punctuation and non-Latin text, select the YouTube row, and open a result
   through Links on this page. Verify loading, audio/video behavior and reconnect on real hardware; a search URL alone
   does not establish playback compatibility. CarPlay may restrict its keyboard independently of this prototype.

## Website interaction boundary

Apple explicitly states that CPMapTemplate's base view does not support direct user interactions:
https://developer.apple.com/documentation/carplay/cpmaptemplate
The reported dead webpage taps are therefore a limitation of the current presentation path. A UIKit tap recognizer,
enabling WKWebView interaction, or changing artwork cannot make general webpage input available through that path.
Native search and link lists are alternatives, not a completed fix for direct tapping, arbitrary forms or site buttons.
CarTV reference images show a separate text-entry screen and a YouTube microphone permission prompt, but do not reveal
its implementation. General website interaction, authenticated services, protected video and microphone permissions
remain independent device-validation tasks. Do not claim that every shortcut or arbitrary website is fully functional.

## Debug field-input experiment

The prototype now includes `CarBrowserInputBridge`, `CarBrowserInputScript` and `CarBrowserFieldEditor`.
If a genuine webpage click reaches an eligible input or textarea, a native CPSearchTemplate editor opens. Its result
is sent to the exact original field in the original frame, using WebKit arguments rather than interpolated code.
Search-like fields can submit their standard HTML form; other fields receive text plus input/change events only.
The keyboard's Search button and the result row both complete the edit. The editor starts empty; it does not preload
or read the field's previous text. The origin and field label appear in its action row.

The script runs in a separate WKContentWorld in each frame. Website-generated clicks cannot open the editor.
Password, payment-autocomplete, one-time-code, disabled and readonly fields are excluded. Text is capped at 4096 UTF-16
units. Navigation, tab switches, Pro loss, Close and disconnect cancel pending edits. Field text, URLs and labels are
not written to diagnostics or logs. The handler and gesture probe are installed only in DEBUG car-browser tabs.

This deliberately does not replace CPMapTemplate or bypass its event overlay. It cannot open an editor when CarPlay
does not deliver the webpage click. It is a test of the downstream path and a way to measure the remaining boundary,
not evidence that CarTV-style touch interaction has been achieved.

### Run the decisive CarPlay check

1. Pull this branch, run `tuist generate --no-open`, then run a signed Debug build.
2. Open Browser and any website, then More → Input test → Open test page.
3. Tap the large search field on that local page. If an editor opens, enter `music & తెలుగు`, then press Search.
   Pass: the local page displays that exact text below the form.
4. Reopen More → Input test to read the counters. They are snapshots taken when the menu opens, not live counters.

| Counter result | Interpretation |
| --- | --- |
| Ready frames is zero | The script has not initialized; investigate page loading or bridge installation first. |
| Ready frames is positive, taps and editor requests stay zero | No webpage input was observed; this matches the documented CarPlay overlay limitation. |
| Webpage taps increase, editor requests do not | The click did not target an eligible field, or no click followed the pointer event. |
| Editor requests increase, editor does not open | Investigate template presentation; the trace records only whether CarPlay accepted it. |
| Editor opens and Applied edits increases | The field-update path returned success; verify the displayed submitted result too. |

Only after that pass should the same sequence be tried on YouTube and other sites. Custom JavaScript widgets,
contenteditable editors, login flows, media gestures, voice input and nonstandard forms are not covered. An Applied
edits count reports the bridge result, not server acceptance or compatibility with every website.

### Browser-layer integration checks

`Tests/BrowserInput/bridge.spec.cjs` loads the production bridge script into an isolated Chromium execution world and
uses real browser clicks. With Playwright and its Chromium browser installed, run:

```bash
node Tests/BrowserInput/bridge.spec.cjs
```

An existing Chromium binary can be supplied through `PLAYCARTV_CHROMIUM_PATH`. This test covers Unicode and code-like
text, input/change events and form submission, script-generated click rejection, sensitive/readonly/disabled fields,
stale targets, length bounds, textarea behavior, iframe targeting and document replacement. Chromium passing is not
WebKit, Xcode or CarPlay validation.

The ten Chromium integration checks passed in the coding environment. The native CarPlay editor and input counters
have not been run in Xcode or on CarPlay hardware. Their presence is not a successful CarPlay feasibility result.

## Validation in the coding environment

Linux cannot run Xcode, Tuist generation, SwiftLint, or the iOS tests here. Added Swift tests cover independent browser ownership/storage, queued-navigation cancellation, safe link selection, Debug-only Pro access, tab isolation/limits/cleanup, encoded YouTube search and rounded artwork. These tests require execution on a Mac. Swift syntax parsing, catalog validation and diff whitespace checks do not establish an Xcode build or visual/device acceptance. This prototype must remain a draft until build, input, lifecycle, and distribution feasibility are verified.
