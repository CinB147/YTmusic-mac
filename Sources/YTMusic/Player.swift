import SwiftUI
import WebKit

struct Playlist: Identifiable, Equatable {
    let id: String        // InnerTube browseId, e.g. "VLPL..."
    let title: String
    let subtitle: String
    let thumbnail: URL?

    var path: String {
        id.hasPrefix("VL") ? "/playlist?list=\(id.dropFirst(2))" : "/browse/\(id)"
    }
}

/// Owns the web view that runs music.youtube.com and mirrors its player state for the native UI.
@MainActor
final class Player: NSObject, ObservableObject {
    static let home = URL(string: "https://music.youtube.com/")!
    static let signIn = URL(string:
        "https://accounts.google.com/ServiceLogin?ltmpl=music&service=youtube&continue=https%3A%2F%2Fwww.youtube.com%2Fsignin%3Faction_handle_signin%3Dtrue%26next%3Dhttps%253A%252F%252Fmusic.youtube.com%252F")!

    @Published var title = ""
    @Published var artist = ""
    @Published var artwork: URL?
    @Published var isPlaying = false
    @Published var position: Double = 0
    @Published var duration: Double = 0
    @Published var volume: Double = 1
    @Published var liked = false
    @Published var shuffle = false
    @Published var playerOpen = false
    @Published var repeatMode = "NONE"
    @Published var path = "/"
    @Published var loggedIn: Bool?
    @Published var playlists: [Playlist] = []
    @Published var isLoading = true

    let webView: WKWebView

    var hasTrack: Bool { !title.isEmpty }

    override init() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.mediaTypesRequiringUserActionForPlayback = []
        config.userContentController.addUserScript(
            WKUserScript(source: Scripts.styleInjection, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        config.userContentController.addUserScript(
            WKUserScript(source: Scripts.bridge, injectionTime: .atDocumentEnd, forMainFrameOnly: true))

        webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = Scripts.userAgent
        webView.allowsBackForwardNavigationGestures = true
        webView.underPageBackgroundColor = NSColor(red: 0.07, green: 0.07, blue: 0.07, alpha: 1)
        super.init()

        config.userContentController.add(self, name: "ytm")
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.load(URLRequest(url: Self.home))
    }

    // MARK: Commands

    private var onMusicSite: Bool { webView.url?.host == "music.youtube.com" }

    private func run(_ call: String) {
        webView.evaluateJavaScript("window.__ytm && window.__ytm.\(call)", completionHandler: nil)
    }

    func togglePlay() { run("toggle()") }
    func next() { run("next()") }
    func previous() { run("prev()") }
    func toggleShuffle() { run("shuffle()") }
    func toggleRepeat() { run("repeat()") }
    func toggleLike() { run("like()") }
    func toggleQueue() { run("queue()") }
    func refreshPlaylists() { run("refresh()") }

    func seek(to seconds: Double) {
        position = seconds
        run("seek(\(seconds))")
    }

    func setVolume(_ value: Double) {
        volume = value
        run("volume(\(value))")
    }

    /// In-page navigation when possible, so the music keeps playing.
    func navigate(_ path: String) {
        if onMusicSite && !isLoading {
            run("nav(\(Scripts.jsString(path)))")
        } else if let url = URL(string: path, relativeTo: Self.home) {
            webView.load(URLRequest(url: url))
        }
    }

    func goBack() { if webView.canGoBack { webView.goBack() } }
    func goForward() { if webView.canGoForward { webView.goForward() } }
    func reload() { webView.reload() }
    func signIn() { webView.load(URLRequest(url: Self.signIn)) }
}

extension Player: WKScriptMessageHandler {
    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
        switch type {
        case "state":
            set(\.title, body["title"] as? String ?? "")
            set(\.artist, body["artist"] as? String ?? "")
            set(\.artwork, (body["art"] as? String).flatMap { $0.isEmpty ? nil : URL(string: $0) })
            set(\.isPlaying, body["playing"] as? Bool ?? false)
            set(\.position, body["position"] as? Double ?? 0)
            set(\.duration, body["duration"] as? Double ?? 0)
            set(\.volume, body["volume"] as? Double ?? 1)
            set(\.liked, body["liked"] as? Bool ?? false)
            set(\.shuffle, body["shuffle"] as? Bool ?? false)
            set(\.playerOpen, body["playerOpen"] as? Bool ?? false)
            set(\.repeatMode, body["repeat"] as? String ?? "NONE")
            set(\.path, body["path"] as? String ?? "/")
        case "session":
            set(\.loggedIn, body["loggedIn"] as? Bool)
        case "playlists":
            let items = body["items"] as? [[String: Any]] ?? []
            set(\.playlists, items.compactMap { item in
                guard let id = item["id"] as? String, let title = item["title"] as? String else { return nil }
                return Playlist(id: id, title: title,
                                subtitle: item["subtitle"] as? String ?? "",
                                thumbnail: (item["thumb"] as? String).flatMap(URL.init(string:)))
            })
            if let error = body["error"] as? String { NSLog("YTMusic: playlist fetch failed: %@", error) }
        default:
            break
        }
    }

    /// Only publish real changes so the UI isn't re-rendered twice a second for nothing.
    private func set<T: Equatable>(_ keyPath: ReferenceWritableKeyPath<Player, T>, _ value: T) {
        if self[keyPath: keyPath] != value { self[keyPath: keyPath] = value }
    }
}

extension Player: WKNavigationDelegate, WKUIDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        isLoading = true
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isLoading = false
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        isLoading = false
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        isLoading = false
    }

    /// Popups (Google sign-in, target=_blank links) open in the same view.
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil { webView.load(navigationAction.request) }
        return nil
    }
}

struct WebView: NSViewRepresentable {
    let webView: WKWebView
    func makeNSView(context: Context) -> WKWebView { webView }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
