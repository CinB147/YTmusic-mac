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
                .frame(height: 84)
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
        HStack(spacing: 16) {
            NowPlaying().frame(maxWidth: .infinity, alignment: .leading)
            Transport().frame(maxWidth: 560)
            Extras().frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .background(Theme.bar)
    }
}

struct NowPlaying: View {
    @EnvironmentObject var player: Player

    var body: some View {
        HStack(spacing: 12) {
            Artwork(url: player.artwork, size: 56, radius: 4)
            VStack(alignment: .leading, spacing: 3) {
                Text(player.hasTrack ? player.title : "Nothing playing")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(player.artist)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.secondary)
                    .lineLimit(1)
            }
            if player.hasTrack {
                IconButton(symbol: player.liked ? "heart.fill" : "heart", size: 14,
                           tint: player.liked ? Theme.accent : Theme.secondary) { player.toggleLike() }
            }
        }
    }
}

struct Transport: View {
    @EnvironmentObject var player: Player
    @State private var scrub: Double?

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 18) {
                IconButton(symbol: "shuffle", size: 13,
                           tint: player.shuffle ? Theme.accent : Theme.secondary) { player.toggleShuffle() }
                IconButton(symbol: "backward.end.fill", size: 16) { player.previous() }
                Button { player.togglePlay() } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color.white))
                }
                .buttonStyle(.plain)
                IconButton(symbol: "forward.end.fill", size: 16) { player.next() }
                IconButton(symbol: player.repeatMode == "ONE" ? "repeat.1" : "repeat", size: 13,
                           tint: player.repeatMode == "NONE" ? Theme.secondary : Theme.accent) { player.toggleRepeat() }
            }
            HStack(spacing: 8) {
                TimeLabel(seconds: scrub ?? player.position)
                Slider(
                    value: Binding(get: { scrub ?? player.position }, set: { scrub = $0 }),
                    in: 0...max(player.duration, 1),
                    onEditingChanged: { editing in
                        if !editing, let target = scrub {
                            player.seek(to: target)
                            scrub = nil
                        }
                    }
                )
                .controlSize(.mini)
                .tint(Theme.accent)
                .disabled(player.duration <= 0)
                TimeLabel(seconds: player.duration)
            }
        }
    }
}

struct Extras: View {
    @EnvironmentObject var player: Player

    var body: some View {
        HStack(spacing: 10) {
            IconButton(symbol: "list.bullet", size: 14,
                       tint: player.playerOpen ? Theme.accent : Theme.secondary) { player.toggleQueue() }
                .help("Queue / now playing")
            Image(systemName: player.volume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .font(.system(size: 12))
                .foregroundStyle(Theme.secondary)
                .frame(width: 20)
            Slider(value: Binding(get: { player.volume }, set: { player.setVolume($0) }), in: 0...1)
                .controlSize(.mini)
                .tint(Theme.accent)
                .frame(width: 100)
        }
    }
}

// MARK: - Small pieces

struct TimeLabel: View {
    let seconds: Double

    var body: some View {
        let total = Int(seconds.isFinite ? max(seconds, 0) : 0)
        Text(String(format: "%d:%02d", total / 60, total % 60))
            .font(.system(size: 11).monospacedDigit())
            .foregroundStyle(Theme.secondary)
            .frame(width: 38)
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
    var tint: Color = Theme.secondary
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(hovering && tint == Theme.secondary ? Color.white : tint)
                .frame(width: 28, height: 28)
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
