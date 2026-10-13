import Foundation

// FAQ answers are prose; wrapping them mid-sentence hurts more than it helps.
// swiftlint:disable line_length
struct FAQEntry: Identifiable {
    let id: Int
    let question: LocalizedStringResource
    let answer: LocalizedStringResource

    static let all: [FAQEntry] = [
        FAQEntry(
            id: 0,
            question: "What should I do if something goes wrong while using the app?",
            answer: "Close Roadivo from the app switcher and open it again. If a channel still won't play, refresh its source in Settings › Manage Sources. Still stuck? Contact us through Roadivo's App Store page."
        ),
        FAQEntry(
            id: 1,
            question: "I bought Roadivo Pro, but it still says I'm not a member.",
            answer: "Open the Pro screen and tap Restore. Make sure you're signed in with the same Apple Account you bought with. Purchases waiting for Ask to Buy approval unlock once approved."
        ),
        FAQEntry(
            id: 2,
            question: "What is a source? Does Roadivo come with channels?",
            answer: "A source is a playlist link, an M3U file, or a media server you own or subscribe to. Roadivo is a player only: it doesn't provide, host or recommend any content."
        ),
        FAQEntry(
            id: 3,
            question: "Where do I find a source?",
            answer: "From an IPTV service you subscribe to (they send an M3U link, a QR code or Xtream login details), or from your own Jellyfin or Emby server. Only add sources you have the right to watch."
        ),
        FAQEntry(
            id: 4,
            question: "I pasted a link and it says the download failed or it isn't a valid channel list.",
            answer: "Check the link opens in Safari, starts with http:// or https://, and that your subscription is active. Some providers limit how many devices can use one link."
        ),
        FAQEntry(
            id: 5,
            question: "My source was added, so why does Home show only some of the channels?",
            answer: "Each group shows its first 20 channels in a row. Tap See All for the rest, or use search."
        ),
        FAQEntry(
            id: 6,
            question: "What do I need to watch in the car?",
            answer: "A car display or wireless adapter that accepts AirPlay video. Start a channel, tap AirPlay and pick it. No AirPlay? Mount your iPhone and use Car Mode. Never watch video while driving."
        ),
        FAQEntry(
            id: 7,
            question: "Does casting need Wi‑Fi?",
            answer: "AirPlay needs your iPhone and the screen on the same network, or a direct connection from an AirPlay adapter. Streams also need mobile data or Wi‑Fi; videos on this iPhone play offline."
        ),
        FAQEntry(
            id: 8,
            question: "Why won't a channel play?",
            answer: "Streams go offline, change address or use a format iPhone can't play. Jellyfin and Emby convert videos automatically; for IPTV, ask your provider for HLS (m3u8) links."
        ),
        FAQEntry(
            id: 9,
            question: "Can I keep watching while I browse?",
            answer: "Yes. Close the player and it keeps going in the mini player, or swipe home for Picture in Picture."
        ),
        FAQEntry(
            id: 10,
            question: "Is my data private?",
            answer: "Everything you add stays on this iPhone. Links and logins are kept in the Keychain. Roadivo has no account, no ads and no tracking."
        )
    ]
}

// swiftlint:enable line_length
