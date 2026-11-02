import SwiftUI

struct MusicView: View {
    @ObservedObject var store = Store.shared
    @State private var showLyricsPane = false
    private let tint = IslandTab.music.tint

    // hasAccess: true if the currently-detected app (or any app) has automation granted
    private var hasAccess: Bool {
        let np = store.playing
        if let bid = np.bundleID {
            // Check the specific app that's playing
            return store.perms[bid] == .granted
        }
        return store.perms.values.contains(.granted)
    }

    // missingApp: name of the playing app that needs permission
    private var missingApp: String? {
        let np = store.playing
        guard let bid = np.bundleID, store.perms[bid] != .granted else { return nil }
        return np.app
    }

    var body: some View {
        let np = store.playing
        Group {
            if np.app != nil { player(np) } else { empty }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: np.app)
        .onAppear {
            store.refreshPermissions()
            store.refreshMusic()
            if store.showLyrics, store.lyrics.status == .synced || store.lyrics.status == .plain {
                showLyricsPane = true
            }
        }
        .onChange(of: store.lyrics.status) { _, status in
            if status == .synced { showLyricsPane = true }
            if status == .notFound { showLyricsPane = false }
        }
    }

    // MARK: now playing
    private func player(_ np: NowPlaying) -> some View {
        HStack(spacing: 20) {
            artwork(np)
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    AppIconView(bundleID: np.bundleID, size: 16)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    Text(sourceLine(np)).font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6)).lineLimit(1)
                    Spacer(minLength: 4)
                    IconButton(symbol: showLyricsPane ? "quote.bubble.fill" : "quote.bubble", size: 24,
                               tint: showLyricsPane ? tint : nil) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            showLyricsPane.toggle()
                        }
                    }
                    .help(showLyricsPane ? "Hide lyrics" : "Show lyrics")
                    .disabled(!store.showLyrics)
                    .opacity(store.showLyrics ? 1 : 0.35)
                    IconButton(symbol: store.showMusicInNotch ? "eye.fill" : "eye.slash.fill", size: 24,
                               tint: store.showMusicInNotch ? tint : nil) { store.showMusicInNotch.toggle() }
                        .help(store.showMusicInNotch ? "Showing in the notch. Click to hide." : "Hidden from the notch. Click to show.")
                }
                Marquee(text: np.title.isEmpty ? "Unknown title" : np.title, size: 18, weight: .bold)
                if !np.artist.isEmpty {
                    Marquee(text: np.artist, size: 12.5, weight: .medium, color: .white.opacity(0.62))
                }
                if showLyricsPane && store.showLyrics {
                    LyricsPane(result: store.lyrics, position: np.position, tint: tint) { seconds in
                        store.seek(to: seconds)
                    }
                    // FIX 2A: bounded frame — never pushes layout upward.
                    .frame(maxHeight: 100)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                progress(np)
                controls(np).padding(.top, 2)
                if !showLyricsPane, let hint = store.mediaHint {
                    HStack(spacing: 6) {
                        Text(hint).font(.system(size: 10.5)).foregroundStyle(.orange).lineLimit(3)
                        Button("Fix") { SettingsWindowController.shared.show(page: .permissions) }
                            .buttonStyle(.plain).font(.system(size: 10.5, weight: .bold)).foregroundStyle(.orange)
                    }
                } else if !showLyricsPane && np.browser && !np.precise {
                    Text("Tip: enable Precise browser mode in Settings → Music for artist, artwork and exact controls.")
                        .font(.system(size: 10)).foregroundStyle(.white.opacity(0.4)).lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // FIX 2A: content must never push upward; fill available space downward.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func sourceLine(_ np: NowPlaying) -> String {
        let app = np.app ?? ""
        if np.source.isEmpty || np.source == app { return app }
        return "\(np.source) · \(app)"
    }

    private func artwork(_ np: NowPlaying) -> some View {
        // FIX 2A: artwork size adapts to available height; never pushes layout above notch.
        GeometryReader { geo in
            let size = min(150, geo.size.height - 24)
            let sz = max(size, 80)
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous).fill(
                        LinearGradient(colors: [tint, Color(red: 0.55, green: 0.40, blue: 1.0)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing))
                    if let u = np.artwork {
                        AsyncImage(url: u) { phase in
                            if let img = phase.image { img.resizable().scaledToFill() } else { Color.clear }
                        }
                    } else {
                        Equalizer(active: np.playing, color: .white.opacity(0.92), bars: 5, maxH: sz * 0.37, barW: 6)
                    }
                }
                .frame(width: sz, height: sz)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white.opacity(0.22), lineWidth: 0.8))
                .shadow(color: tint.opacity(np.playing ? 0.5 : 0.12), radius: 18, y: 8)

                AppIconView(bundleID: np.bundleID, size: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .shadow(color: .black.opacity(0.45), radius: 6, y: 2)
                    .offset(x: 9, y: 9)
            }
            .scaleEffect(np.playing ? 1 : 0.93)
            .animation(.spring(response: 0.5, dampingFraction: 0.6), value: np.playing)
            .padding(.trailing, 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .frame(width: 160)
    }

    @ViewBuilder private func progress(_ np: NowPlaying) -> some View {
        if np.duration > 0 {
            HStack(spacing: 8) {
                Text(mmss(np.position)).font(.system(size: 10, design: .monospaced)).foregroundStyle(.white.opacity(0.5))
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.14))
                        Capsule().fill(tint)
                            .frame(width: g.size.width * CGFloat(min(max(np.position / np.duration, 0), 1)))
                            .animation(.linear(duration: 1), value: np.position)
                    }
                    // Tap or drag anywhere on the bar to seek
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { v in
                            let ratio = max(0, min(1, v.location.x / g.size.width))
                            store.seek(to: np.duration * Double(ratio))
                        }
                    )
                }
                .frame(height: 12)   // taller hit area, visually still 4pt via Capsule
                .contentShape(Rectangle())
                .overlay(alignment: .top) {
                    Spacer().frame(height: 4)   // keep visual bar pinned to top of hit zone
                }
                Text(mmss(np.duration)).font(.system(size: 10, design: .monospaced)).foregroundStyle(.white.opacity(0.5))
            }
        }
    }

    private func controls(_ np: NowPlaying) -> some View {
        HStack(spacing: 26) {
            ctl("backward.fill", 17) { store.music("previous track") }
            ctl(np.playing ? "pause.circle.fill" : "play.circle.fill", 38) { store.music("playpause") }
            ctl("forward.fill", 17) { store.music("next track") }
        }
    }

    private func ctl(_ icon: String, _ size: CGFloat, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: size))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: size + 14, height: size + 10)
                .contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    // MARK: nothing playing
    private var empty: some View {
        VStack(spacing: 9) {
            Image(systemName: "music.note.list").font(.system(size: 26)).foregroundStyle(tint)
            Text("Nothing playing").font(.system(size: 16, weight: .semibold))
            if hasAccess {
                Text("Play something in Apple Music, Spotify or a browser tab.")
                    .font(.system(size: 12)).foregroundStyle(.white.opacity(0.6))
                HStack {
                    PillButton("Apple Music") { store.launch("com.apple.Music") }
                    PillButton("Spotify") { store.launch("com.spotify.client") }
                }
            } else {
                Text("Inertia needs permission to see what's playing\(missingApp.map { " in \($0)" } ?? "").")
                    .font(.system(size: 12)).foregroundStyle(.white.opacity(0.6)).multilineTextAlignment(.center)
                PillButton("Open Permissions", tint: tint) {
                    SettingsWindowController.shared.show(page: .permissions)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Synced lyrics pane
private struct LyricsPane: View {
    let result: LyricsResult
    let position: Double
    let tint: Color
    let onSeek: (Double) -> Void

    private var current: Int? {
        guard result.status == .synced else { return nil }
        return result.lines.lastIndex { $0.timeMs >= 0 && Double($0.timeMs) / 1000 <= position }
    }

    var body: some View {
        Group {
            switch result.status {
            case .synced:
                synced
            case .plain:
                plain
            case .loading:
                centered {
                    ProgressView().controlSize(.small)
                    Text("Finding lyrics…").font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
                }
            case .instrumental:
                centered {
                    Image(systemName: "music.quarternote.3").font(.system(size: 22)).foregroundStyle(tint)
                    Text("Instrumental").font(.system(size: 11.5, weight: .medium)).foregroundStyle(.white.opacity(0.6))
                }
            case .notFound:
                centered {
                    Image(systemName: "quote.bubble").font(.system(size: 20)).foregroundStyle(.white.opacity(0.35))
                    Text("No lyrics found on LRCLIB.").font(.system(size: 11)).foregroundStyle(.white.opacity(0.45))
                }
            case .error:
                centered {
                    Image(systemName: "wifi.exclamationmark").font(.system(size: 20)).foregroundStyle(.orange.opacity(0.8))
                    Text("Couldn't reach LRCLIB.").font(.system(size: 11)).foregroundStyle(.white.opacity(0.45))
                }
            case .off, .none:
                centered {
                    Text("Lyrics are off.").font(.system(size: 11)).foregroundStyle(.white.opacity(0.4))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.white.opacity(0.07), lineWidth: 0.6)
        )
    }

    private var synced: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 5) {
                    ForEach(Array(result.lines.enumerated()), id: \.offset) { index, line in
                        let active = index == current
                        Text(line.text.isEmpty ? "♪" : line.text)
                            .font(.system(size: active ? 13 : 11, weight: active ? .bold : .medium))
                            .foregroundStyle(active ? Color.white : Color.white.opacity(index < (current ?? 0) ? 0.28 : 0.5))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if line.timeMs >= 0 { onSeek(Double(line.timeMs) / 1000) }
                            }
                            .id(index)
                            .animation(.easeOut(duration: 0.2), value: active)
                    }
                }
                .padding(.vertical, 8).padding(.horizontal, 11)
            }
            .mask(
                LinearGradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.1),
                    .init(color: .black, location: 0.9),
                    .init(color: .clear, location: 1)
                ], startPoint: .top, endPoint: .bottom)
            )
            .onAppear {
                if let current { proxy.scrollTo(current, anchor: .center) }
            }
            .onChange(of: current) { _, new in
                guard let new else { return }
                withAnimation(.easeInOut(duration: 0.35)) {
                    proxy.scrollTo(new, anchor: .center)
                }
            }
        }
    }

    private var plain: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 5) {
                ForEach(Array(result.lines.enumerated()), id: \.offset) { _, line in
                    Text(line.text.isEmpty ? " " : line.text)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.62))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.vertical, 8).padding(.horizontal, 11)
        }
        .mask(
            LinearGradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.08),
                .init(color: .black, location: 0.92),
                .init(color: .clear, location: 1)
            ], startPoint: .top, endPoint: .bottom)
        )
    }

    private func centered<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 7) { content() }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
