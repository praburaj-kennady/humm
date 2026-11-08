import SwiftUI
import WebKit

// Hooks play through YouTube's own embedded player (we never host or cut audio).
// The player is a small web page inside the app. Swift tells it what to do
// ("load this video at 0:52", "pause") and it reports back the time and state.

enum YouTubeEvent {
    case ready
    case state(Int) // -1 unstarted, 0 ended, 1 playing, 2 paused, 3 buffering, 5 cued
    case time(Double) // seconds
    case error(Int)
}

@MainActor
final class YouTubeController: NSObject {
    let webView: WKWebView
    var onEvent: ((YouTubeEvent) -> Void)?

    override init() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = [] // the app may start sound itself
        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 640, height: 360), configuration: config)
        super.init()
        config.userContentController.add(MessageRelay(self), name: "yt")
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        webView.isUserInteractionEnabled = false // taps go to our own controls
        // YouTube wants to know which site the player is on.
        webView.loadHTMLString(Self.page, baseURL: URL(string: "https://praburaj-kennady.github.io/humm/"))
    }

    func load(_ hook: Hook, autoplay: Bool) {
        let id = hook.sourceId.filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
        let start = Double(hook.startMs) / 1000
        run(autoplay ? "hLoad('\(id)', \(start))" : "hCue('\(id)', \(start))")
    }

    func play() { run("hPlay()") }
    func pause() { run("hPause()") }
    func seek(toSeconds s: Double) { run("hSeek(\(s))") }

    private func run(_ js: String) {
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    fileprivate func receive(_ body: Any) {
        guard let dict = body as? [String: Any], let type = dict["type"] as? String else { return }
        switch type {
        case "ready": onEvent?(.ready)
        case "state": onEvent?(.state((dict["state"] as? NSNumber)?.intValue ?? -1))
        case "time": onEvent?(.time((dict["t"] as? NSNumber)?.doubleValue ?? 0))
        case "error": onEvent?(.error((dict["code"] as? NSNumber)?.intValue ?? 0))
        default: break
        }
    }

    private static let page = """
    <!doctype html>
    <html><head>
    <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1">
    <style>html,body{margin:0;height:100%;background:#000;overflow:hidden}#p{position:absolute;inset:0;width:100%;height:100%}</style>
    </head><body><div id="p"></div>
    <script>
    var player = null, ready = false, queued = null, timer = null;
    function post(m) { window.webkit.messageHandlers.yt.postMessage(m); }
    function whenReady(f) { if (ready) f(); else queued = f; }
    function tick() { stopTick(); timer = setInterval(function () { post({ type: 'time', t: player.getCurrentTime() }); }, 200); }
    function stopTick() { if (timer) { clearInterval(timer); timer = null; } }
    function onYouTubeIframeAPIReady() {
      player = new YT.Player('p', {
        host: 'https://www.youtube-nocookie.com',
        width: '100%', height: '100%',
        playerVars: { playsinline: 1, controls: 0, disablekb: 1, fs: 0, rel: 0, iv_load_policy: 3, modestbranding: 1, origin: location.origin },
        events: {
          onReady: function () { ready = true; post({ type: 'ready' }); if (queued) { var q = queued; queued = null; q(); } },
          onStateChange: function (e) { post({ type: 'state', state: e.data }); if (e.data === 1) tick(); else stopTick(); },
          onError: function (e) { post({ type: 'error', code: e.data }); }
        }
      });
    }
    function hLoad(id, start) { whenReady(function () { player.loadVideoById({ videoId: id, startSeconds: start }); }); }
    function hCue(id, start) { whenReady(function () { player.cueVideoById({ videoId: id, startSeconds: start }); }); }
    function hPlay() { whenReady(function () { player.playVideo(); }); }
    function hPause() { whenReady(function () { player.pauseVideo(); }); }
    function hSeek(s) { whenReady(function () { player.seekTo(s, true); }); }
    </script>
    <script src="https://www.youtube.com/iframe_api"></script>
    </body></html>
    """
}

/// Passes messages from the web page to the controller without keeping it alive forever.
private final class MessageRelay: NSObject, WKScriptMessageHandler {
    weak var target: YouTubeController?
    init(_ target: YouTubeController) { self.target = target }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        let body = message.body
        MainActor.assumeIsolated { target?.receive(body) }
    }
}

/// Shows the one shared player. SwiftUI may call this more than once; it's always the same web view.
struct YouTubeSurface: UIViewRepresentable {
    let controller: YouTubeController
    func makeUIView(context: Context) -> WKWebView { controller.webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
