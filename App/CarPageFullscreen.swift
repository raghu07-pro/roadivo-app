import WebKit

/// Full screen for a car tab's page (owner, 2026-10-27): an iPhone gives pages no Fullscreen API, so YouTube's button
/// said "Your browser doesn't support full screen". The script gives them one: a video opens in the iPhone's own
/// player, as before inline playback (owner: "as old"); anything else fills the page and the car hides its bar.
@MainActor
final class CarPageFullscreen: NSObject, WKScriptMessageHandler {
    static let messageName = "roadivoFullscreen"
    /// The page went full screen, or left it.
    var onChange: ((Bool) -> Void)?

    func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) {
        onChange?(message.body as? Bool ?? false)
    }

    /// Ends the page's full screen, when the car leaves its own.
    static let exit = "document.exitFullscreen && document.exitFullscreen();"

    static let script = WKUserScript(
        source: """
        (() => {
          let current = null;
          const style = document.createElement('style');
          style.textContent = '.roadivo-fullscreen { position: fixed !important; inset: 0 !important; ' +
            'width: 100vw !important; height: 100vh !important; max-width: none !important; ' +
            'max-height: none !important; margin: 0 !important; z-index: 2147483647 !important; ' +
            'background: #000 !important; } html.roadivo-fullscreen-on, html.roadivo-fullscreen-on body ' +
            '{ overflow: hidden !important; }';
          const tell = isOn => window.webkit.messageHandlers.\(messageName).postMessage(isOn);
          const changed = () => {
            for (const name of ['fullscreenchange', 'webkitfullscreenchange']) {
              document.dispatchEvent(new Event(name, {bubbles: true}));
            }
            window.dispatchEvent(new Event('resize'));
          };
          const enter = function () {
            // The video itself, in the iPhone's player: filling the page left YouTube's player as it was and only hid
            // the car's bar (owner: "expanding the browser screen and hiding the top menu bar").
            const inside = this instanceof HTMLVideoElement ? this : this.querySelector && this.querySelector('video');
            const video = inside || Array.from(document.querySelectorAll('video')).find(each => !each.paused);
            if (video && typeof video.webkitEnterFullscreen === 'function') {
              try {
                video.webkitEnterFullscreen();
                return Promise.resolve();
              } catch (error) {}
            }
            if (!style.isConnected) (document.head || document.documentElement).appendChild(style);
            if (current && current !== this) current.classList.remove('roadivo-fullscreen');
            current = this;
            this.classList.add('roadivo-fullscreen');
            document.documentElement.classList.add('roadivo-fullscreen-on');
            tell(true);
            setTimeout(changed, 0);
            return Promise.resolve();
          };
          const exit = () => {
            if (!current) return Promise.resolve();
            current.classList.remove('roadivo-fullscreen');
            current = null;
            document.documentElement.classList.remove('roadivo-fullscreen-on');
            tell(false);
            setTimeout(changed, 0);
            return Promise.resolve();
          };
          const define = (name, get) => {
            try { Object.defineProperty(Document.prototype, name, {get, configurable: true}); } catch (error) {}
          };
          for (const name of ['fullscreenEnabled', 'webkitFullscreenEnabled']) define(name, () => true);
          for (const name of ['fullscreenElement', 'webkitFullscreenElement', 'webkitCurrentFullScreenElement']) {
            define(name, () => current);
          }
          define('webkitIsFullScreen', () => current !== null);
          for (const name of ['requestFullscreen', 'webkitRequestFullscreen', 'webkitRequestFullScreen']) {
            Element.prototype[name] = enter;
          }
          for (const name of ['exitFullscreen', 'webkitExitFullscreen', 'webkitCancelFullScreen']) {
            Document.prototype[name] = exit;
          }
        })();
        """,
        injectionTime: .atDocumentStart,
        forMainFrameOnly: true
    )
}
