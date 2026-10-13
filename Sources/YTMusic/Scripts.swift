import Foundation

/// JavaScript and CSS injected into music.youtube.com.
/// The web page stays the playback engine; the native UI talks to it through `window.__ytm`.
enum Scripts {
    static let userAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.5 Safari/605.1.15"

    /// Hides the web app's own sidebar and player bar (the native ones replace them).
    static let css = #"""
    ytmusic-guide-renderer, #guide-wrapper, #mini-guide, #guide-spacer,
    tp-yt-app-drawer, ytmusic-nav-bar .left-content { display: none !important; }
    ytmusic-app-layout, ytmusic-app {
      --ytmusic-guide-width: 0px !important;
      --ytmusic-mini-guide-width: 0px !important;
      --ytmusic-player-bar-height: 0px !important;
    }
    ytmusic-player-bar, ytmusic-miniplayer, #player-bar-background {
      opacity: 0 !important; pointer-events: none !important;
      height: 0 !important; min-height: 0 !important; overflow: hidden !important;
    }
    ytmusic-nav-bar { left: 0 !important; width: 100% !important; }
    html, body, ytmusic-app { background: #121212 !important; }
    ::-webkit-scrollbar { width: 10px; }
    ::-webkit-scrollbar-thumb { background: #3a3a3a; border-radius: 5px; }
    ::-webkit-scrollbar-track { background: transparent; }
    """#

    static var styleInjection: String {
        """
        (function () {
          if (location.hostname !== 'music.youtube.com') return;
          var add = function () {
            if (document.getElementById('ytm-native-style')) return;
            var s = document.createElement('style');
            s.id = 'ytm-native-style';
            s.textContent = \(jsString(css));
            (document.head || document.documentElement).appendChild(s);
          };
          add();
          document.addEventListener('DOMContentLoaded', add);
        })();
        """
    }

    static let bridge = #"""
    (function () {
      if (location.hostname !== 'music.youtube.com' || window.__ytm) return;

      const post = (type, payload) => {
        try { window.webkit.messageHandlers.ytm.postMessage(Object.assign({ type }, payload || {})); } catch (e) {}
      };
      const $ = (sel) => document.querySelector(sel);
      const click = (sel) => { const el = $(sel); if (el) { el.click(); return true; } return false; };
      const video = () => $('video');
      const cfg = (key) => (window.ytcfg && window.ytcfg.get) ? window.ytcfg.get(key) : undefined;
      const text = (sel) => { const el = $(sel); return el ? (el.textContent || '').trim() : ''; };

      // Newer "miniplayer" markup first, then the older ytmusic-player-bar.
      const SEL = {
        play: '.ytmusicPlayerControlsPlayPauseButton button, ytmusic-player-bar #play-pause-button',
        next: '.ytmusicPlayerControlsNextButton button, ytmusic-player-bar .next-button',
        prev: '.ytmusicPlayerControlsPreviousButton button, ytmusic-player-bar .previous-button',
        shuffle: '.ytmusicPlayerControlsShuffleButton button, ytmusic-player-bar .shuffle',
        repeat: '.ytmusicPlayerControlsRepeatButton button, ytmusic-player-bar .repeat',
        like: 'ytmusic-miniplayer like-button-view-model button, ' +
          'ytmusic-player-bar ytmusic-like-button-renderer #button-shape-like button',
        page: 'ytmusic-miniplayer ytmusic-track-info, ytmusic-player-bar .toggle-player-page-button'
      };
      const ROUTES = { '/': 'FEmusic_home', '/explore': 'FEmusic_explore', '/library': 'FEmusic_library_landing' };
      const pressed = (sel) => { const el = $(sel); return !!el && el.getAttribute('aria-pressed') === 'true'; };
      const playerOpen = () => {
        const layout = $('ytmusic-app-layout');
        return !!layout && layout.getAttribute('player-ui-state') === 'PLAYER_PAGE_OPEN';
      };

      // ---- player state -> native ----
      function bigArt(url) {
        if (!url) return '';
        return url.replace(/=w\d+-h\d+[^?]*/, '=w544-h544-l90-rj');
      }

      function readState() {
        const v = video();
        const md = navigator.mediaSession && navigator.mediaSession.metadata;
        let title = '', artist = '', art = '';
        if (md) {
          title = md.title || '';
          artist = md.artist || '';
          if (md.artwork && md.artwork.length) art = md.artwork[md.artwork.length - 1].src || '';
        }
        if (!title) title = text('.ytmusicTrackInfoTitle') || text('ytmusic-player-bar .title');
        if (!artist) artist = text('.ytmusicTrackInfoByline a');
        if (!art) { const img = $('img.ytmusicTrackInfoThumbnail, ytmusic-player-bar img.image'); if (img) art = img.src || ''; }

        const mp = $('#movie_player');
        let volume = v ? v.volume : 1;
        if (mp && mp.getVolume) { try { volume = mp.getVolume() / 100; } catch (e) {} }

        const oldBar = $('ytmusic-player-bar');
        const oldLike = $('ytmusic-player-bar ytmusic-like-button-renderer');
        let repeat = 'NONE';
        if (oldBar) {
          repeat = oldBar.getAttribute('repeat-mode') || oldBar.getAttribute('repeat-mode_') || 'NONE';
        } else if (pressed(SEL.repeat)) {
          repeat = /one|1/i.test($(SEL.repeat).getAttribute('title') || '') ? 'ONE' : 'ALL';
        }

        return {
          title, artist, art: bigArt(art),
          playing: !!(v && !v.paused && !v.ended),
          position: v && isFinite(v.currentTime) ? v.currentTime : 0,
          duration: v && isFinite(v.duration) ? v.duration : 0,
          volume,
          liked: pressed(SEL.like) || (!!oldLike && oldLike.getAttribute('like-status') === 'LIKE'),
          shuffle: pressed(SEL.shuffle),
          repeat,
          playerOpen: playerOpen(),
          path: location.pathname + location.search
        };
      }
      setInterval(() => post('state', readState()), 500);

      // ---- library playlists (InnerTube, using the page's own session) ----
      async function authHeader() {
        const m = document.cookie.match(/(?:^|;\s*)(?:SAPISID|__Secure-3PAPISID)=([^;]+)/);
        if (!m) return null;
        const ts = Math.floor(Date.now() / 1000);
        const data = new TextEncoder().encode(ts + ' ' + m[1] + ' ' + location.origin);
        const buf = await crypto.subtle.digest('SHA-1', data);
        const hex = Array.from(new Uint8Array(buf)).map((b) => b.toString(16).padStart(2, '0')).join('');
        return 'SAPISIDHASH ' + ts + '_' + hex;
      }

      async function browse(body, continuation) {
        const headers = { 'Content-Type': 'application/json', 'X-Origin': location.origin };
        const auth = await authHeader();
        if (auth) headers['Authorization'] = auth;
        headers['X-Goog-AuthUser'] = String(cfg('SESSION_INDEX') || '0');
        let url = '/youtubei/v1/browse?prettyPrint=false&key=' + encodeURIComponent(cfg('INNERTUBE_API_KEY') || '');
        const payload = Object.assign({ context: cfg('INNERTUBE_CONTEXT') }, body);
        if (continuation) {
          url += '&ctoken=' + encodeURIComponent(continuation) + '&continuation=' + encodeURIComponent(continuation);
          payload.continuation = continuation;
        }
        const res = await fetch(url, { method: 'POST', credentials: 'include', headers, body: JSON.stringify(payload) });
        if (!res.ok) throw new Error('browse ' + res.status);
        return res.json();
      }

      function walk(node, visit) {
        if (!node || typeof node !== 'object') return;
        if (Array.isArray(node)) { for (const n of node) walk(n, visit); return; }
        for (const key in node) {
          if (visit(key, node[key]) === false) continue;
          walk(node[key], visit);
        }
      }
      const runs = (t) => (t && t.runs ? t.runs.map((r) => r.text).join('') : '');

      function parsePlaylists(json, out, seen) {
        let next = null;
        walk(json, (key, value) => {
          if (key === 'musicTwoRowItemRenderer' && value) {
            const ep = value.navigationEndpoint && value.navigationEndpoint.browseEndpoint;
            if (ep && ep.browseId && !seen.has(ep.browseId)) {
              let thumb = '';
              walk(value.thumbnailRenderer, (k, v) => {
                if (k === 'thumbnails' && Array.isArray(v) && v.length && !thumb) thumb = v[v.length - 1].url || '';
              });
              seen.add(ep.browseId);
              out.push({ id: ep.browseId, title: runs(value.title), subtitle: runs(value.subtitle), thumb });
            }
            return false;
          }
          if (key === 'nextContinuationData' && value && value.continuation) next = value.continuation;
          if (key === 'continuationCommand' && value && value.token) next = value.token;
        });
        return next;
      }

      async function loadPlaylists() {
        const loggedIn = !!cfg('LOGGED_IN');
        post('session', { loggedIn });
        if (!loggedIn) { post('playlists', { items: [] }); return; }
        try {
          const out = [], seen = new Set();
          let next = parsePlaylists(await browse({ browseId: 'FEmusic_liked_playlists' }), out, seen);
          for (let i = 0; next && i < 8; i++) {
            next = parsePlaylists(await browse({}, next), out, seen);
          }
          post('playlists', { items: out });
        } catch (e) {
          post('playlists', { items: [], error: String(e) });
        }
      }

      function whenReady(tries) {
        if (cfg('INNERTUBE_CONTEXT')) { loadPlaylists(); return; }
        if (tries > 0) setTimeout(() => whenReady(tries - 1), 500);
      }
      whenReady(40);

      // ---- commands <- native ----
      window.__ytm = {
        toggle() {
          if (click(SEL.play)) return;
          const v = video(); if (v) { v.paused ? v.play() : v.pause(); }
        },
        next() { click(SEL.next); },
        prev() { click(SEL.prev); },
        seek(t) { const v = video(); if (v) v.currentTime = t; },
        volume(x) {
          const mp = $('#movie_player');
          if (mp && mp.setVolume) {
            mp.setVolume(Math.round(x * 100));
            if (x > 0 && mp.unMute) mp.unMute();
          } else { const v = video(); if (v) v.volume = x; }
        },
        shuffle() { click(SEL.shuffle); },
        repeat() { click(SEL.repeat); },
        like() { click(SEL.like); },
        queue() { click(SEL.page); },
        // In-page navigation (no reload), so playback is never interrupted.
        nav(path) {
          let browseId = ROUTES[path];
          const list = path.match(/^\/playlist\?list=([^&]+)/);
          if (list) browseId = 'VL' + list[1];
          const direct = path.match(/^\/browse\/([^?]+)/);
          if (direct) browseId = direct[1];
          const app = $('ytmusic-app');
          if (!browseId || !app) { location.href = path; return; }
          if (playerOpen()) click(SEL.page);
          app.dispatchEvent(new CustomEvent('yt-navigate', {
            bubbles: true, composed: true, detail: { endpoint: { browseEndpoint: { browseId } } }
          }));
        },
        refresh: loadPlaylists
      };
    })();
    """#

    static func jsString(_ s: String) -> String {
        let data = try! JSONSerialization.data(withJSONObject: [s])
        let json = String(data: data, encoding: .utf8)!
        return String(json.dropFirst().dropLast())
    }
}
