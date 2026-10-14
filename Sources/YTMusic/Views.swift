import SwiftUI

enum Theme {
    static let accent = Color(red: 0.11, green: 0.73, blue: 0.33)
    static let base = Color(red: 0.07, green: 0.07, blue: 0.07)
    static let sidebar = Color.black
    static let bar = Color(red: 0.09, green: 0.09, blue: 0.09)
    static let hover = Color.white.opacity(0.08)
    static let secondary = Color.white.opacity(0.6)
}

struct ContentView: View {
    @EnvironmentObject var player: Player

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Sidebar()
                    .frame(width: 250)
                ZStack(alignment: .top) {
                    WebView(webView: player.webView)
                    if player.isLoading {
                        ProgressView().progressViewStyle(.linear).tint(Theme.accent)
                    }
                }
            }
            Divider().overlay(Color.white.opacity(0.08))
            PlayerBar()
                .frame(height: 92)
        }
        .background(Theme.base)
        .ignoresSafeArea()
    }
}

// MARK: - Sidebar

struct Sidebar: View {
    @EnvironmentObject var player: Player

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Spacer()
                IconButton(symbol: "chevron.left", size: 13) { player.goBack() }
                IconButton(symbol: "chevron.right", size: 13) { player.goForward() }
            }
            .padding(.horizontal, 10)
            .frame(height: 44)

            VStack(spacing: 2) {
                NavRow(symbol: "house.fill", title: "Home", path: "/")
                NavRow(symbol: "safari", title: "Explore", path: "/explore")
                NavRow(symbol: "square.stack.fill", title: "Library", path: "/library")
            }
            .padding(.horizontal, 8)

            HStack {
                Text("PLAYLISTS")
                    .font(.system(size: 11, weight: .bold))
                    .kerning(1)
                    .foregroundStyle(Theme.secondary)
                Spacer()
                IconButton(symbol: "arrow.clockwise", size: 11) { player.refreshPlaylists() }
            }
            .padding(.leading, 20)
            .padding(.trailing, 10)
            .padding(.top, 22)
            .padding(.bottom, 6)

            ScrollView {
                LazyVStack(spacing: 2) {
                    if player.loggedIn == false {
                        SignInPrompt()
                    } else {
                        ForEach(player.playlists) { playlist in
                            PlaylistRow(playlist: playlist)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 12)
            }
        }
        .background(Theme.sidebar)
    }
}

struct SignInPrompt: View {
    @EnvironmentObject var player: Player

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sign in to see your playlists and use your Premium account.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.secondary)
            Button { player.signIn() } label: {
                Text("Sign in")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.white))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct NavRow: View {
    @EnvironmentObject var player: Player
    let symbol: String
    let title: String
    let path: String

    var body: some View {
        let selected = player.path == path
        RowButton(selected: selected) { player.navigate(path) } label: {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 16))
                    .frame(width: 24)
                Text(title).font(.system(size: 14, weight: .semibold))
                Spacer()
            }
            .foregroundStyle(selected ? Color.white : Theme.secondary)
            .padding(.horizontal, 12)
            .frame(height: 38)
        }
    }
}

struct PlaylistRow: View {
    @EnvironmentObject var player: Player
    let playlist: Playlist

    var body: some View {
        let selected = player.path == playlist.path
        RowButton(selected: selected) { player.navigate(playlist.path) } label: {
            HStack(spacing: 10) {
                Artwork(url: playlist.thumbnail, size: 40, radius: 4)
                VStack(alignment: .leading, spacing: 2) {
                    Text(playlist.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(selected ? Theme.accent : Color.white)
                        .lineLimit(1)
                    if !playlist.subtitle.isEmpty {
                        Text(playlist.subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .frame(height: 52)
        }
    }
}

// MARK: - Player bar

struct PlayerBar: View {
    @EnvironmentObject var player: Player

    var body: some View {
        HStack(spacing: 20) {
            NowPlaying().frame(maxWidth: .infinity, alignment: .leading)
            Transport().frame(minWidth: 320, maxWidth: 600)
            Extras().frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 18)
        .frame(maxHeight: .infinity)
        .background(Theme.bar)
    }
}

struct NowPlaying: View {
    @EnvironmentObject var player: Player

    var body: some View {
        HStack(spacing: 14) {
            Artwork(url: player.artwork, size: 58, radius: 6)
            VStack(alignment: .leading, spacing: 4) {
                Text(player.hasTrack ? player.title : "Nothing playing")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if !player.artist.isEmpty {
                    Text(player.artist)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.secondary)
                        .lineLimit(1)
                }
            }
            if player.hasTrack {
                IconButton(symbol: player.liked ? "heart.fill" : "heart", size: 17, box: 34,
                           tint: player.liked ? Theme.accent : Theme.secondary) { player.toggleLike() }
            }
        }
    }
}

struct Transport: View {
    @EnvironmentObject var player: Player
    @State private var scrub: Double?

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 14) {
                ToggleIcon(symbol: "shuffle", isOn: player.shuffle) { player.toggleShuffle() }
                IconButton(symbol: "backward.end.fill", size: 20, box: 38, tint: .white.opacity(0.85)) { player.previous() }
                PlayButton(isPlaying: player.isPlaying) { player.togglePlay() }
                IconButton(symbol: "forward.end.fill", size: 20, box: 38, tint: .white.opacity(0.85)) { player.next() }
                ToggleIcon(symbol: player.repeatMode == "ONE" ? "repeat.1" : "repeat",
                           isOn: player.repeatMode != "NONE") { player.toggleRepeat() }
            }
            HStack(spacing: 10) {
                TimeLabel(seconds: scrub ?? player.position, alignment: .trailing)
                BarSlider(
                    value: Binding(get: { scrub ?? player.position }, set: { scrub = $0 }),
                    range: 0...max(player.duration, 1),
                    onEditingChanged: { editing in
                        if !editing, let target = scrub {
                            player.seek(to: target)
                            scrub = nil
                        }
                    }
                )
                .disabled(player.duration <= 0)
                TimeLabel(seconds: player.duration, alignment: .leading)
            }
        }
    }
}

struct Extras: View {
    @EnvironmentObject var player: Player

    var body: some View {
        HStack(spacing: 12) {
            IconButton(symbol: "list.bullet", size: 16, box: 34,
                       tint: player.playerOpen ? Theme.accent : Theme.secondary) { player.toggleQueue() }
                .help("Queue / now playing")
            HStack(spacing: 8) {
                Image(systemName: volumeSymbol)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.secondary)
                    .frame(width: 22, alignment: .leading)
                BarSlider(value: Binding(get: { player.volume }, set: { player.setVolume($0) }), range: 0...1)
                    .frame(width: 96)
            }
        }
    }

    private var volumeSymbol: String {
        switch player.volume {
        case 0: return "speaker.slash.fill"
        case ..<0.34: return "speaker.wave.1.fill"
        case ..<0.67: return "speaker.wave.2.fill"
        default: return "speaker.wave.3.fill"
        }
    }
}

struct PlayButton: View {
    let isPlaying: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.black)
                .offset(x: isPlaying ? 0 : 1.5)   // optically centre the triangle
                .frame(width: 42, height: 42)
                .background(Circle().fill(Color.white))
                .scaleEffect(hovering ? 1.06 : 1)
                .animation(.easeOut(duration: 0.12), value: hovering)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

/// Shuffle / repeat: green with a dot underneath when active.
struct ToggleIcon: View {
    let symbol: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        IconButton(symbol: symbol, size: 16, box: 34, tint: isOn ? Theme.accent : Theme.secondary, action: action)
            .overlay(alignment: .bottom) {
                Circle().fill(Theme.accent).frame(width: 4, height: 4).opacity(isOn ? 1 : 0)
            }
    }
}

/// Thin progress-style slider; the knob appears on hover or drag.
struct BarSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var onEditingChanged: (Bool) -> Void = { _ in }
    @State private var hovering = false
    @State private var dragging = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        GeometryReader { geo in
            let span = max(range.upperBound - range.lowerBound, 0.0001)
            let fraction = min(max((value - range.lowerBound) / span, 0), 1)
            let active = (hovering || dragging) && isEnabled
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.2)).frame(height: 4)
                Capsule().fill(active ? Theme.accent : Color.white.opacity(0.9))
                    .frame(width: geo.size.width * fraction, height: 4)
                Circle().fill(Color.white)
                    .frame(width: 12, height: 12)
                    .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
                    .offset(x: (geo.size.width - 12) * fraction)
                    .opacity(active ? 1 : 0)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        if !dragging {
                            dragging = true
                            onEditingChanged(true)
                        }
                        let x = min(max(gesture.location.x / max(geo.size.width, 1), 0), 1)
                        value = range.lowerBound + span * x
                    }
                    .onEnded { _ in
                        dragging = false
                        onEditingChanged(false)
                    }
            )
            .onHover { hovering = $0 }
        }
        .frame(height: 16)
    }
}

// MARK: - Small pieces

struct TimeLabel: View {
    let seconds: Double
    var alignment: Alignment = .center

    var body: some View {
        let total = Int(seconds.isFinite ? max(seconds, 0) : 0)
        Text(String(format: "%d:%02d", total / 60, total % 60))
            .font(.system(size: 11, weight: .medium).monospacedDigit())
            .foregroundStyle(Theme.secondary)
            .frame(width: 40, alignment: alignment)
    }
}

struct Artwork: View {
    let url: URL?
    let size: CGFloat
    let radius: CGFloat

    var body: some View {
        AsyncImage(url: url) { image in
            image.resizable().aspectRatio(contentMode: .fill)
        } placeholder: {
            ZStack {
                Color.white.opacity(0.08)
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.4))
                    .foregroundStyle(Theme.secondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: radius))
    }
}

struct IconButton: View {
    let symbol: String
    let size: CGFloat
    var box: CGFloat = 28
    var tint: Color = Theme.secondary
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(hovering && tint != Theme.accent ? Color.white : tint)
                .frame(width: box, height: box)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

struct RowButton<Label: View>: View {
    let selected: Bool
    let action: () -> Void
    @ViewBuilder let label: () -> Label
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            label()
                .background(RoundedRectangle(cornerRadius: 6)
                    .fill(selected ? Color.white.opacity(0.12) : (hovering ? Theme.hover : Color.clear)))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
