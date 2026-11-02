import SwiftUI
import AppKit

// MARK: - Island shape
/// The single surface used by the island. It is drawn in the fixed panel's
/// coordinate space, anchored to the physical notch, so width, height, corner
/// radius and the top flare all move on one spring instead of two backgrounds
/// racing each other.
nonisolated struct IslandShape: Shape, Animatable {
    var width: CGFloat
    var height: CGFloat
    var centerOffset: CGFloat = 0
    var flare: CGFloat = 0

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>> {
        get { .init(.init(width, height), .init(centerOffset, flare)) }
        set {
            width = newValue.first.first
            height = newValue.first.second
            centerOffset = newValue.second.first
            flare = newValue.second.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let w = max(width, 1)
        let h = max(height, 1)
        let cx = rect.midX + centerOffset
        let x0 = cx - w / 2
        let x1 = cx + w / 2

        // Radius and flare are both derived from the animated height, so they
        // stretch and settle with the body instead of on a separate timeline.
        let radius = min(28,
                         max(16, 16 + (h - 50) * 0.21),
                         min(h * 0.45, w * 0.45))
        let f = min(max(flare, 0), min(6, w * 0.08))
        let top = rect.minY
        let bottom = top + h

        var path = Path()
        path.move(to: CGPoint(x: x0 - f, y: top))
        path.addQuadCurve(to: CGPoint(x: x0, y: top + f * 1.5),
                          control: CGPoint(x: x0, y: top))
        path.addLine(to: CGPoint(x: x0, y: bottom - radius))
        path.addQuadCurve(to: CGPoint(x: x0 + radius, y: bottom),
                          control: CGPoint(x: x0, y: bottom))
        path.addLine(to: CGPoint(x: x1 - radius, y: bottom))
        path.addQuadCurve(to: CGPoint(x: x1, y: bottom - radius),
                          control: CGPoint(x: x1, y: bottom))
        path.addLine(to: CGPoint(x: x1, y: top + f * 1.5))
        path.addQuadCurve(to: CGPoint(x: x1 + f, y: top),
                          control: CGPoint(x: x1, y: top))
        path.closeSubpath()
        return path
    }
}

// MARK: - Root
struct NotchView: View {
    static var openSize: CGSize {
        CGSize(width: CGFloat(Store.shared.featureSettings.openPanelWidth),
               height: IslandLayout.openPanelHeight)
    }
    static let alertSize = CGSize(width: 440, height: 116)

    let notch: NotchMetrics
    @ObservedObject var store = Store.shared
    @ObservedObject var feature = Store.shared.featureSettings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var w: CGFloat
    @State private var h: CGFloat
    @State private var flare: CGFloat
    @State private var hoverExpanded = false
    @State private var hoverWork: DispatchWorkItem?
    @State private var artworkTint = IslandTab.music.tint

    init(notch: NotchMetrics) {
        self.notch = notch
        _w = State(initialValue: notch.width)
        _h = State(initialValue: notch.height)
        _flare = State(initialValue: NotchView.flare(for: notch.height))
    }

    var body: some View {
        ZStack(alignment: .top) {
            islandBackground
            content
            if store.mode == .collapsed && !store.introActive && !(hoverExpanded && canHover) {
                // A transparent hit area that exactly matches the collapsed shape.
                // It owns both the click-to-open gesture and the hover delay.
                Color.clear
                    .contentShape(Rectangle())
                    .frame(width: w, height: h)
                    .offset(x: notch.centerOffset)
                    .onHover { scheduleHover($0) }
                    .onTapGesture(perform: openPanel)
            }
        }
        .frame(width: NotchPanel.size.width, height: NotchPanel.size.height, alignment: .top)
        .overlay {
            shape.stroke(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .clear, location: 8 / NotchPanel.size.height),
                        .init(color: .white.opacity(0.10), location: 24 / NotchPanel.size.height),
                        .init(color: .white.opacity(0.06), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 2
            )
        }
        .clipShape(shape)
        .environment(\.colorScheme, .dark)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear { applyGeometry(animated: false) }
        .onChange(of: targetSize) { _, _ in applyGeometry() }
        .onChange(of: store.introActive) { _, _ in applyGeometry() }
        .onChange(of: store.mode) { _, mode in
            hoverWork?.cancel()
            if mode != .collapsed { hoverExpanded = false }
            if mode != .open { store.showMenu = false }
        }
        .onChange(of: store.liveStatus) { _, status in
            hoverWork?.cancel()
            if status != nil { hoverExpanded = false }
        }
        .onChange(of: store.musicShown) { _, shown in
            NSLog("INERTIA music wing visible=\(shown) app=\(store.playing.app ?? "nil") playing=\(store.playing.playing) precise=\(store.playing.precise) peek=\(store.peek) mode=\(store.mode) wing=\(store.wing)")
            if !shown {
                hoverWork?.cancel()
                hoverExpanded = false
            }
        }
        .onChange(of: store.wing) { _, wing in
            NSLog("INERTIA music wing width=\(wing) musicShown=\(store.musicShown) peek=\(store.peek)")
        }
        .onChange(of: store.isFullscreenActive) { _, active in
            // Entering fullscreen (or hiding for it) must not leave the hover
            // card armed to reappear when the panel comes back.
            if active {
                hoverWork?.cancel()
                hoverExpanded = false
            }
        }
        .onChange(of: feature.hideNotchWhenFullscreen) { _, _ in
            if !canHover {
                hoverWork?.cancel()
                hoverExpanded = false
            }
        }
        .onDisappear { hoverWork?.cancel() }
        .task(id: store.playing.artwork) {
            let tint = await ArtworkTint.color(for: store.playing.artwork)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.35)) {
                artworkTint = tint ?? IslandTab.music.tint
            }
        }
    }

    // MARK: Geometry

    /// One source of truth for the island's visible size.
    private var targetSize: CGSize {
        // TASK 2: intro takes over the whole size calculation.
        if store.introActive {
            let width = CGFloat(feature.openPanelWidth)
            let height = notch.height + 6 + IslandLayout.introContentHeight
            return CGSize(width: width, height: height)
        }
        switch store.mode {
        case .open:
            return Self.openSize
        case .alert:
            return Self.alertSize
        case .collapsed:
            if hoverExpanded && canHover {
                return CGSize(width: IslandLayout.hoverWidth,
                              height: IslandLayout.hoverCardHeight(notchHeight: notch.height))
            }
            let width = max(notch.width + store.wing, CGFloat(feature.islandWidth))
            let expansion = store.liveStatus == nil ? 0 : CGFloat(feature.hudExpansion) + 6
            let baseHeight = store.musicShown
                ? notch.height + IslandLayout.collapsedMusicExtraHeight
                : notch.height
            return CGSize(width: width, height: baseHeight + expansion)
        }
    }

    private var shape: IslandShape {
        IslandShape(width: w, height: h, centerOffset: notch.centerOffset, flare: flare)
    }

    private static func flare(for height: CGFloat) -> CGFloat {
        min(5, max(1.5, height * 0.06))
    }

    private var liquid: Animation {
        .inertiaLiquid(speed: store.animSpeed, reduceMotion: reduceMotion)
    }

    private func applyGeometry(animated: Bool = true) {
        let size = targetSize
        store.hitSize = size
        let targetFlare = Self.flare(for: size.height)
        guard animated else {
            w = size.width
            h = size.height
            flare = targetFlare
            return
        }
        withAnimation(liquid) {
            w = size.width
            h = size.height
            flare = targetFlare
        }
    }

    // MARK: Hover

    /// Hover is only allowed while the island is collapsed with music showing.
    /// Alerts and live status (volume/brightness HUDs) always win.
    private var canHover: Bool {
        store.mode == .collapsed &&
        store.musicShown &&
        store.liveStatus == nil &&
        !(feature.hideNotchWhenFullscreen && store.isFullscreenActive)
    }

    private func scheduleHover(_ inside: Bool) {
        hoverWork?.cancel()
        guard canHover else {
            if hoverExpanded { hoverExpanded = false }
            return
        }
        let delay = (inside ? 0.12 : 0.25) / max(store.animSpeed, 0.1)
        let work = DispatchWorkItem {
            guard canHover else { return }
            withAnimation(liquid) {
                hoverExpanded = inside
            }
        }
        hoverWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func openPanel() {
        hoverWork?.cancel()
        withAnimation(liquid) {
            hoverExpanded = false
            store.tab = .launcher
            store.mode = .open
        }
    }

    // MARK: Background

    private var islandBackground: some View {
        let tabTint: Color
        if store.tab == .music, store.musicShown {
            tabTint = artworkTint
        } else {
            tabTint = store.tab.tint
        }
        return ZStack(alignment: .top) {
            // BUG 5: collapsed island base is solid black, no material.
            if store.mode == .collapsed {
                Color.black.opacity(0.98)
            } else {
                InertiaIslandBackground(tint: tabTint)
            }
            if store.mode == .collapsed && store.musicShown { musicTint }
            if store.mode == .alert { alertTint }
        }
        .animation(.easeInOut(duration: 0.4), value: store.tab)
        .animation(.easeInOut(duration: 0.3), value: artworkTint)
        .animation(.easeInOut(duration: 0.25), value: store.mode)
    }

    private var musicTintOpacity: Double {
        guard store.mode == .collapsed,
              store.musicShown,
              store.liveStatus == nil,
              !(hoverExpanded && canHover) else { return 0 }
        return 1
    }

    /// BUG 5 fix: the collapsed music tint is a LinearGradient overlay on the left
    /// wing only, fading from tint.opacity(0.55) at the leading edge to .clear at
    /// 70% of the wing width — so it vanishes completely BEFORE the notch centre.
    /// Applied as a masked overlay clipped to the island shape; no solid Rectangle.
    private var musicTint: some View {
        let tintWidth = max((w - notch.width) / 2, 0)
        // The gradient occupies the left wing then is transparent for the rest.
        return GeometryReader { _ in
            LinearGradient(
                stops: [
                    .init(color: artworkTint.opacity(0.55), location: 0),
                    .init(color: artworkTint.opacity(0.20), location: 0.55),
                    .init(color: .clear, location: 0.70),
                    .init(color: .clear, location: 1.0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            // Scale the gradient so it spans exactly the wing width, then
            // place it at the leading edge offset by the notch center.
            .frame(width: tintWidth + notch.width / 2, height: h)
            .frame(width: w, alignment: .leading)
            .offset(x: notch.centerOffset - (w / 2 - tintWidth - notch.width / 2) / 2)
        }
        .frame(width: w, height: h)
        .offset(x: notch.centerOffset)
        .opacity(musicTintOpacity)
        .animation(.easeInOut(duration: 0.30 / max(store.animSpeed, 0.1)), value: artworkTint)
        .animation(.easeInOut(duration: 0.18 / max(store.animSpeed, 0.1)), value: hoverExpanded)
        .animation(.easeInOut(duration: 0.22 / max(store.animSpeed, 0.1)), value: store.mode)
    }

    private var alertTint: some View {
        LinearGradient(colors: [(store.alertInfo?.tint ?? .orange).opacity(0.22), .clear],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
            .frame(width: w, height: h)
            .offset(x: notch.centerOffset)
            .opacity(store.mode == .alert ? 1 : 0)
            .animation(.easeInOut(duration: 0.25 / max(store.animSpeed, 0.1)), value: store.mode)
    }

    // MARK: Content

    private var contentKey: String {
        if store.introActive { return "intro" }
        switch store.mode {
        case .open: return "open"
        case .alert: return "alert"
        case .collapsed:
            if store.liveStatus != nil { return "hud" }
            if hoverExpanded && canHover { return "hover" }
            return "collapsed"
        }
    }

    private var contentTransition: AnyTransition {
        reduceMotion ? .opacity
            : .opacity.combined(with: .scale(scale: 0.92, anchor: .top))
    }

    private var contentAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.18) : liquid.delay(0.04)
    }

    private var content: some View {
        ZStack(alignment: .top) {
            stage
        }
        .id(contentKey)
        .transition(contentTransition)
        .animation(contentAnimation, value: contentKey)
        .frame(width: w, height: h, alignment: .top)
        .offset(x: notch.centerOffset)
    }

    @ViewBuilder private var stage: some View {
        // TASK 2: intro takes priority over all other states.
        if store.introActive {
            IntroView(notchH: notch.height)
        } else {
            switch store.mode {
            case .collapsed:
                if let status = store.liveStatus {
                    LiveStatusBar(status: status, notch: notch)
                } else if hoverExpanded && canHover {
                    HoverMusicCard(notchH: notch.height, artworkTint: artworkTint, onOpen: openPanel)
                        .onHover { scheduleHover($0) }
                } else {
                    CollapsedWings(notch: notch,
                                   height: store.musicShown ? notch.height + IslandLayout.collapsedMusicExtraHeight : notch.height,
                                   artworkTint: artworkTint)
                }
            case .open:
                OpenPanel(notchH: notch.height)
            case .alert:
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill((store.alertInfo?.tint ?? .orange).opacity(0.25)).frame(width: 46, height: 46)
                        Image(systemName: store.alertInfo?.icon ?? "bell.fill").font(.system(size: 17)).foregroundStyle(store.alertInfo?.tint ?? .orange)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.alertInfo?.title ?? "").font(.system(size: 15, weight: .semibold)).lineLimit(1)
                        Text(store.alertInfo?.subtitle ?? "").font(.system(size: 11)).foregroundStyle(.white.opacity(0.55)).lineLimit(1)
                    }
                    Spacer()
                    if let url = store.alertInfo?.joinURL {
                        PillButton("Join", tint: store.alertInfo?.tint ?? .orange) { NSWorkspace.shared.open(url); store.dismissAlert() }
                    }
                    if store.alertInfo?.snooze == true { PillButton("Snooze 5m") { store.snooze() } }
                    PillButton(store.alertInfo?.sticky == true ? "Done" : "OK", tint: store.alertInfo?.tint ?? .orange) { store.dismissAlert() }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20).padding(.top, notch.height + 4).padding(.bottom, 12)
                .frame(width: NotchView.alertSize.width, height: NotchView.alertSize.height)
            }
        }
    }
}

// MARK: - Collapsed island: emoji, music and focus live in the "wings" either side of the notch
struct CollapsedWings: View {
    let notch: NotchMetrics
    var height: CGFloat
    var artworkTint: Color
    @ObservedObject var store = Store.shared
    @ObservedObject var feature = Store.shared.featureSettings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var liquid: Animation {
        .inertiaLiquid(speed: store.animSpeed, reduceMotion: reduceMotion)
    }

    var body: some View {
        let wing = store.wing
        let total = max(notch.width + wing, CGFloat(feature.islandWidth))
        if wing > 0 {
            // Allocate the wings by their real content widths first, then split
            // the remaining space evenly. This keeps every item clear of the
            // physical notch instead of letting a fixed ZStack overlap it.
            let available = max(total - notch.width, 0)
            let half = available / 2
            let leftContent = store.collapsedLeftContentWidth
            let rightContent = store.collapsedRightContentWidth
            let leftWidth = max(leftContent, min(half, available - rightContent))
            let rightWidth = max(available - leftWidth, 0)
            let np = store.playing
            HStack(spacing: 0) {
                leftWing(np).frame(width: leftWidth, alignment: .leading)
                Color.clear.frame(width: notch.width)
                rightWing(np, width: rightWidth).frame(width: rightWidth, alignment: .trailing)
            }
            .frame(width: total, height: height)
            .transition(.opacity)
        }
    }

    @ViewBuilder private func leftWing(_ np: NowPlaying) -> some View {
        HStack(spacing: IslandLayout.collapsedWingSpacing) {
            if store.showsLeftEmoji {
                if feature.leftEmojiUseLottie {
                    // UI-6: size controlled by IslandLayout.collapsedLottieSize.
                    LottieView(name: "Loader_cat", loop: true, animationSpeed: 1.0,
                               size: IslandLayout.collapsedLottieSize)
                        .frame(width: IslandLayout.collapsedLottieSize,
                               height: IslandLayout.collapsedLottieSize)
                } else {
                    Text(feature.notchEmoji.isEmpty ? "🤍" : feature.notchEmoji)
                        .font(.system(size: feature.notchEmojiSize))
                        .lineLimit(1)
                }
            }

            if store.musicShown {
                ArtworkThumb(url: np.artwork, size: IslandLayout.collapsedArtworkSize)
                    .shadow(color: artworkTint.opacity(0.35), radius: 5)
            } else if store.focusVisible {
                Image(systemName: store.phase.icon)
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(IslandTab.focus.tint)
            }

            if store.privacyActive {
                PrivacyDots(mic: store.micInUse,
                            camera: store.cameraInUse,
                            screen: store.screenSharing,
                            micApp: store.micAppName,
                            micBundle: store.micAppBundleID,
                            cameraApp: store.cameraAppName,
                            cameraBundle: store.cameraAppBundleID,
                            screenApp: store.screenAppName,
                            screenBundle: store.screenAppBundleID)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .padding(.leading, IslandLayout.collapsedWingInset)
        .padding(.trailing, IslandLayout.collapsedWingNotchGap)
        .animation(liquid, value: store.privacyActive)
    }

    @ViewBuilder private func rightWing(_ np: NowPlaying, width: CGFloat) -> some View {
        HStack(spacing: IslandLayout.collapsedWingSpacing) {
            if store.peek && store.musicShown {
                Marquee(text: np.title.isEmpty ? "Now playing" : np.title, size: 11.5, weight: .semibold)
                    .frame(width: max(width - wingStatusWidth - 29, 28))
                    .padding(.trailing, 2)
            } else if store.focusVisible {
                Text(clock(store.focusLeft)).font(.system(size: 12, weight: .medium, design: .monospaced))
                    .padding(.trailing, 2)
            } else if store.musicShown {
                Equalizer(active: np.playing, color: artworkTint, bars: 4, maxH: 13)
            }
            if store.showBatteryInNotch, let b = store.battery, b.present {
                HStack(spacing: 4) {
                    Image(systemName: b.symbol)
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(b.tint)
                    Text("\(b.percent)%")
                        .font(.system(size: 9.5, weight: .semibold))
                        .monospacedDigit()
                }
                .padding(.horizontal, 4)
            }
            wingStatus
            // TASK 3A: keyboard lock reminder icon in right wing
            if store.keyboardLocked {
                Image(systemName: "keyboard")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(Color.orange)
            }
            if store.showsRightEmoji {
                Text(feature.rightNotchEmoji.isEmpty ? "✨" : feature.rightNotchEmoji)
                    .font(.system(size: feature.notchEmojiSize))
                    .lineLimit(1)
            }
        }
        .padding(.leading, IslandLayout.collapsedWingNotchGap)
        .padding(.trailing, IslandLayout.collapsedWingInset)
    }

    private var wingStatusWidth: CGFloat {
        store.showNetworkInNotch && store.network?.connected == false ? 18 : 0
    }

    @ViewBuilder private var wingStatus: some View {
        if store.showNetworkInNotch, let n = store.network, !n.connected {
            Image(systemName: "wifi.slash")
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(.orange)
                .help("No internet connection")
        }
    }
}

// MARK: - Hover now-playing card (UI-5c: 3-row layout — header, transport, volume)
struct HoverMusicCard: View {
    let notchH: CGFloat
    let artworkTint: Color
    let onOpen: () -> Void
    @ObservedObject var store = Store.shared

    var body: some View {
        let np = store.playing

        VStack(alignment: .leading, spacing: IslandLayout.hc5RowGap) {

            // ── Row 1: artwork | title/artist | source ──────────────────────
            HStack(alignment: .center, spacing: 12) {
                ArtworkThumb(url: np.artwork,
                             size: IslandLayout.hc5ArtworkSize,
                             corner: IslandLayout.hc5ArtworkCorner)
                    .shadow(color: artworkTint.opacity(0.3), radius: 6, y: 3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(np.title.isEmpty ? "Unknown title" : np.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(np.artist.isEmpty ? "" : np.artist)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let app = np.app, !app.isEmpty {
                    Text(app)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                        .lineLimit(1)
                }
            }
            .frame(height: IslandLayout.hc5HeaderHeight)
            .contentShape(Rectangle())
            .onTapGesture(perform: onOpen)

            // ── Row 2: transport (prev | play/pause | next | mute) ──────────
            HStack(spacing: 0) {
                Spacer()
                transportBtn("backward.fill", size: 22) { store.music("previous track") }
                Spacer()
                transportBtn(np.playing ? "pause.fill" : "play.fill", size: 28, primary: true) {
                    store.music("playpause")
                }
                Spacer()
                transportBtn("forward.fill", size: 22) { store.music("next track") }
                Spacer()
                transportBtn(muteSymbol, size: 18) {
                    let m = !AudioManager.shared.isMuted
                    SystemOutputVolume.setMuted(m)
                    AudioManager.shared.isMuted = m
                }
                Spacer()
            }
            .frame(height: IslandLayout.hc5ControlsHeight)

            // ── Row 3: volume (speaker | slider with knob | percentage) ─────
            HoverVolumeRow(accentColor: artworkTint)
                .frame(height: IslandLayout.hc5VolumeHeight)

        }
        .padding(.horizontal, IslandLayout.hoverPadH)
        .padding(.top, notchH + IslandLayout.hoverPadTop)
        .padding(.bottom, IslandLayout.hc5BottomPad)
        .frame(width: IslandLayout.hoverWidth,
               height: IslandLayout.hoverCardHeight(notchHeight: notchH),
               alignment: .top)
    }

    // plain flat icon button; InertiaPressStyle gives the 0.94× feedback
    private func transportBtn(_ symbol: String, size: CGFloat,
                              primary: Bool = false,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(.white)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: size + 12, height: IslandLayout.hc5ControlsHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(InertiaPressStyle())
    }

    private var muteSymbol: String {
        if AudioManager.shared.isMuted { return "speaker.slash.fill" }
        let v = AudioManager.shared.outputVolume
        if v > 0.66 { return "speaker.wave.2.fill" }
        if v > 0.33 { return "speaker.wave.1.fill" }
        if v > 0    { return "speaker.fill" }
        return "speaker.slash.fill"
    }
}

// MARK: - UI-5c: Volume row — always-visible horizontal slider with white knob
private struct HoverVolumeRow: View {
    let accentColor: Color
    @ObservedObject private var audio = AudioManager.shared
    @State private var dragValue: Float? = nil
    @State private var thumbScale: CGFloat = 1.0
    @State private var monitor: Any? = nil
    @State private var scrollAcc: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var rm

    private var volume: Float { dragValue ?? audio.outputVolume }
    private var pct: Int { Int(round(volume * 100)) }

    private var speakerSymbol: String {
        if audio.isMuted { return "speaker.slash.fill" }
        let v = audio.outputVolume
        if v > 0.66 { return "speaker.wave.2.fill" }
        if v > 0.33 { return "speaker.wave.1.fill" }
        if v > 0    { return "speaker.fill" }
        return "speaker.slash.fill"
    }

    var body: some View {
        HStack(spacing: 8) {
            // Small speaker icon (mute toggle)
            Button {
                let m = !audio.isMuted
                SystemOutputVolume.setMuted(m)
                audio.isMuted = m
            } label: {
                Image(systemName: speakerSymbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: 16, height: 24)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())

            // Slider (full remaining width, with white knob)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 4)
                    Capsule()
                        .fill(accentColor)
                        .frame(width: g.size.width * CGFloat(volume), height: 4)
                    Circle()
                        .fill(.white)
                        .frame(width: IslandLayout.hc5ThumbSize,
                               height: IslandLayout.hc5ThumbSize)
                        .scaleEffect(thumbScale)
                        .animation(.inertiaLiquid(speed: 1, reduceMotion: rm), value: thumbScale)
                        .offset(x: CGFloat(volume) * (g.size.width - IslandLayout.hc5ThumbSize))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in
                            thumbScale = 1.2
                            dragValue = Float(max(0, min(1, v.location.x / g.size.width)))
                        }
                        .onEnded { _ in
                            thumbScale = 1.0
                            if let d = dragValue {
                                SystemOutputVolume.setVolume(Double(d))
                                audio.outputVolume = d
                                dragValue = nil
                            }
                        }
                )
            }
            .frame(height: 24)

            // Percentage (fixed width so slider doesn't jitter)
            Text("\(pct)%")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: 34, alignment: .trailing)
        }
        .onAppear {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { e in
                let inv: CGFloat = e.isDirectionInvertedFromDevice ? -1 : 1
                scrollAcc += e.scrollingDeltaY * inv *
                             (e.hasPreciseScrollingDeltas ? 0.01 : 0.05)
                if abs(scrollAcc) > 0.001 {
                    let nv = max(0, min(1, audio.outputVolume + Float(scrollAcc)))
                    SystemOutputVolume.setVolume(Double(nv))
                    audio.outputVolume = nv
                    scrollAcc = 0
                }
                return e
            }
        }
        .onDisappear { if let m = monitor { NSEvent.removeMonitor(m) } }
    }
}

private struct HoverCircleButton: View {
    let symbol: String
    let size: CGFloat
    let iconSize: CGFloat
    let fill: Color
    let iconColor: Color
    let primary: Bool
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(fill)
                    .overlay(Circle().fill(.white.opacity(hover && !primary ? 0.14 : 0)))
                    .overlay(Circle().strokeBorder(.white.opacity(primary ? 0 : 0.08), lineWidth: 0.6))
                Image(systemName: symbol)
                    .font(.system(size: iconSize, weight: .bold))
                    .foregroundStyle(iconColor)
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(width: size, height: size)
            .opacity(primary && hover ? 0.88 : 1)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .animation(.easeOut(duration: 0.14), value: hover)
    }
}

struct PrivacyDots: View {
    let mic: Bool
    let camera: Bool
    let screen: Bool
    var micApp: String? = nil
    var micBundle: String? = nil
    var cameraApp: String? = nil
    var cameraBundle: String? = nil
    var screenApp: String? = nil
    var screenBundle: String? = nil
    @ObservedObject private var store = Store.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var liquid: Animation {
        .inertiaLiquid(speed: store.animSpeed, reduceMotion: reduceMotion)
    }

    private var indicatorTransition: AnyTransition {
        .scale(scale: 0.72).combined(with: .opacity)
    }

    var body: some View {
        // Fixed-size app icons with a real gap between them, so the coloured
        // badges never sit on top of the artwork or a neighbouring icon.
        HStack(spacing: IslandLayout.privacyIconSpacing) {
            if mic {
                sourceIndicator(bundle: micBundle,
                                fallbackSystemName: "mic.fill",
                                color: .orange,
                                help: micApp.map { "Microphone in use by \($0)" } ?? "Microphone in use")
                    .transition(indicatorTransition)
            }
            if camera {
                sourceIndicator(bundle: cameraBundle,
                                fallbackSystemName: "video.fill",
                                color: .green,
                                help: cameraApp.map { "Camera in use by \($0)" } ?? "Camera in use")
                    .transition(indicatorTransition)
            }
            if screen {
                sourceIndicator(bundle: screenBundle,
                                fallbackSystemName: "rectangle.dashed",
                                color: .blue,
                                help: screenApp.map { "Screen shared by \($0)" } ?? "Screen shared")
                    .transition(indicatorTransition)
            }
        }
        .animation(liquid, value: mic)
        .animation(liquid, value: camera)
        .animation(liquid, value: screen)
    }

    private func sourceIndicator(bundle: String?, fallbackSystemName: String,
                                 color: Color, help: String) -> some View {
        AppIconView(bundleID: bundle, size: 14,
                    fallbackSystemName: fallbackSystemName,
                    fallbackColor: color)
            .clipShape(RoundedRectangle(cornerRadius: 3.5, style: .continuous))
            .overlay(alignment: .bottomTrailing) {
                // A small corner badge: the icon stays readable because the
                // badge sits over the rounded corner, not the glyph.
                Circle()
                    .fill(color)
                    .frame(width: 5.5, height: 5.5)
                    .overlay(Circle().strokeBorder(.black.opacity(0.65), lineWidth: 0.7))
            }
            .frame(width: IslandLayout.privacyIconSize,
                   height: IslandLayout.privacyIconSize)
            .help(help)
            .accessibilityLabel(help)
    }
}

// MARK: - Open panel
struct OpenPanel: View {
    let notchH: CGFloat
    @ObservedObject var store = Store.shared
    @ObservedObject var feature = Store.shared.featureSettings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var liquid: Animation {
        .inertiaLiquid(speed: store.animSpeed, reduceMotion: reduceMotion)
    }

    // FIX 1: order driven by IslandTab.headerOrder; launcher is last before "...".
    private var headerTabs: [(icon: String, tab: IslandTab)] {
        IslandTab.headerOrder.map { tab in (tab.icon, tab) }
    }

    var body: some View {
        // BUG 1 fix: The background (InertiaIslandBackground) is drawn by the
        // parent ZStack and fills the whole island shape from y=0. The VStack
        // here is ONLY for layout — no extra Rectangle or Color at the top.
        VStack(spacing: 0) {
            if store.mode != .collapsed {
                header
                // Hairline divider spans only the content width (inside contentInset).
                Divider()
                    .padding(.top, IslandLayout.verticalSpacing / 2)
                    .padding(.bottom, IslandLayout.verticalSpacing / 2)
                    .opacity(0.25)
            }

            Group {
                switch store.tab {
                case .launcher: LauncherView()
                case .tasks: TasksView()
                case .notes: NotesView()
                case .remind: RemindView()
                case .music: MusicView()
                case .focus: FocusView()
                case .shelf: ShelfView()
                case .calendar: CalendarView()
                case .settings: SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .id(store.tab)
            .transition(.opacity)
            .animation(liquid, value: store.tab)
        }
        // Anchor the stack to the top of its fixed frame. Without this the
        // VStack is centred inside the fixed-size frame below, so taller or
        // shorter tab content moves the header and divider up or down.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .clipped()
        .padding(.horizontal, IslandLayout.contentInset)
        // Fixed inset for every tab: notch height + 6 pt, never per-tab.
        .padding(.top, IslandLayout.headerTopInset(notchHeight: notchH))
        .padding(.bottom, 14)
        .foregroundStyle(.white)
        // Keep the top edge pinned. Only the tab content below the divider may
        // change; the header never animates position.
        .frame(width: NotchView.openSize.width,
               height: NotchView.openSize.height,
               alignment: .top)
        .onChange(of: store.mode) { _, mode in if mode != .open { store.showMenu = false } }
    }

    // BUG 2 fix: ZStack(center) with TabIconCapsule truly centered, title left, chevron right.
    private var header: some View {
        ZStack(alignment: .center) {
            // CENTER layer: capsule with all tab icons — truly centered on the panel.
            TabIconCapsule(tabs: headerTabs, moreButton: moreButton, select: select)

            // TOP layer: title (left) + [keyboard][lock][chevron] (right).
            HStack(spacing: 0) {
                // Title: max 90pt so nothing overlaps centered capsule at min 600pt width (TASK 3).
                Text(store.tab.title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .frame(maxWidth: 90, alignment: .leading)

                Spacer(minLength: 0)

                // Right button group: [keyboard] [lock], spacing 8.
                // UI-4: Removed collapse chevron (redundant with Esc key)
                HStack(spacing: 8) {
                    // A) Keyboard Lock button (TASK 3A)
                    KeyboardLockButton()

                    // B) Lock / hide island button (TASK 3B)
                    HideIslandButton()
                }
            }
        }
        .frame(height: IslandLayout.headerHeight)
        // Note: horizontal padding is already applied by the outer VStack's .padding(.horizontal).
    }

    private var moreButton: some View {
        Button {
            withAnimation(liquid) {
                store.tab = .launcher
                store.showMenu = true
            }
        } label: {
            // BUG 2: unselected state — light gray glyph, NO background, NO outline.
            Image(systemName: "ellipsis")
                .font(.system(size: 12, weight: .bold))
                .frame(width: 30, height: 30)
                .foregroundStyle(.white.opacity(store.showMenu ? 0.95 : 0.55))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Add to Launcher")
        .accessibilityLabel("More")
    }

    private func select(_ tab: IslandTab) {
        withAnimation(liquid) {
            store.tab = tab
            store.showMenu = false
        }
    }
}

// MARK: - Tab icon capsule (BUG 2 fix)
/// One Capsule wrapping an HStack of icon buttons. Uses .fixedSize() so the
/// capsule always hugs its content exactly — no clipping, no ScrollView.
private struct TabIconCapsule: View {
    let tabs: [(icon: String, tab: IslandTab)]
    let moreButton: AnyView
    let select: (IslandTab) -> Void
    @ObservedObject var store = Store.shared

    init(tabs: [(icon: String, tab: IslandTab)],
         moreButton: some View,
         select: @escaping (IslandTab) -> Void) {
        self.tabs = tabs
        self.moreButton = AnyView(moreButton)
        self.select = select
    }

    var body: some View {
        // 10 items (9 tabs + "...") must fit beside the title and the
        // keyboard/lock/collapse buttons even at the 600pt minimum width.
        HStack(spacing: 2) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { _, item in
                TabIconButton(
                    icon: item.icon,
                    tab: item.tab,
                    isSelected: store.tab == item.tab,
                    action: { select(item.tab) }
                )
            }
            moreButton
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 4)
        .fixedSize()                       // capsule hugs its content, never clips
        .background(
            Capsule(style: .continuous)
                .fill(.white.opacity(0.07))
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(.white.opacity(0.10), lineWidth: 0.8)
        )
    }
}

// MARK: - Tab icon button (BUG 2 fix)
/// 30×30 icon button inside the shared capsule.
/// Unselected: light gray glyph only — NO background circle, NO outline.
/// Selected: filled circle in the tab tint, dark glyph.
private struct TabIconButton: View {
    let icon: String
    let tab: IslandTab
    let isSelected: Bool
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            ZStack {
                if isSelected {
                    Circle().fill(tab.tint)
                }
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.black : Color.white.opacity(hover ? 0.90 : 0.55))
            }
            .frame(width: 30, height: 30)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .help(tab.title)
        .accessibilityLabel(tab.title)
        .animation(.easeOut(duration: 0.14), value: hover)
        .animation(.easeOut(duration: 0.14), value: isSelected)
    }
}

// MARK: - Focus
struct FocusView: View {
    @ObservedObject var store = Store.shared

    private var tint: Color {
        switch store.phase {
        case .work: return IslandTab.focus.tint
        case .shortBreak: return Color(red: 0.38, green: 0.90, blue: 0.66)
        case .longBreak: return Color(red: 0.66, green: 0.60, blue: 1.00)
        }
    }

    var body: some View {
        HStack(spacing: 20) {
            ring
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 5) {
                    phaseChip(.work, "Focus")
                    phaseChip(.shortBreak, "Short")
                    phaseChip(.longBreak, "Long")
                    Spacer(minLength: 0)
                    Text("\(store.focusSessionsToday) today")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.42))
                }
                MiniStepper(label: "Focus", value: $store.workMin, range: 1...180, step: 5)
                MiniStepper(label: "Short break", value: $store.breakMin, range: 1...60, step: 1)
                MiniStepper(label: "Long break", value: $store.longBreakMin, range: 1...90, step: 5)
                HStack(spacing: 8) {
                    PillButton(store.focusRunning ? "Pause" : "Start", tint: tint) {
                        if store.focusRunning { store.focusRunning = false }
                        else if store.focusLeft <= 0 { store.startFocusPhase(store.phase) }
                        else { store.focusRunning = true }
                    }
                    PillButton("Reset") { store.resetFocus() }
                    PillButton("Skip") { store.skipPhase() }
                }
                .padding(.top, 1)
                HStack(spacing: 12) {
                    Toggle("Auto breaks", isOn: $store.autoStartBreaks)
                    Toggle("Auto focus", isOn: $store.autoStartFocus)
                    Toggle("Keep awake", isOn: $store.keepAwake)
                }
                .toggleStyle(.switch).controlSize(.mini).font(.system(size: 10.5))
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var ring: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.10), lineWidth: 9)
            Circle().trim(from: 0, to: CGFloat(store.focusTotal - store.focusLeft) / CGFloat(max(store.focusTotal, 1)))
                .stroke(tint, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: store.focusLeft)
            VStack(spacing: 1) {
                Text(store.phase.title).font(.system(size: 9.5, weight: .bold)).foregroundStyle(tint)
                    .contentTransition(.opacity)
                Text(clock(store.focusLeft)).font(.system(size: 26, weight: .medium, design: .monospaced))
                Text(store.sessionsUntilLongBreak == 1 ? "long break next" : "\(store.sessionsUntilLongBreak) to long break")
                    .font(.system(size: 9)).foregroundStyle(.white.opacity(0.42))
                Text("\(store.focusSecondsToday / 60) min today")
                    .font(.system(size: 9)).foregroundStyle(.white.opacity(0.3))
            }
        }.frame(width: 150, height: 150)
    }

    private func phaseChip(_ p: FocusPhase, _ label: String) -> some View {
        Chip(text: label, on: store.phase == p, tint: tint) {
            store.startFocusPhase(p)
        }
        .help("Start \(p.title.lowercased())")
    }
}




struct MenuItemRow: View {
    let icon: String
    let title: String
    var shortcut: String? = nil
    let action: () -> Void
    @State private var hover = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 16)
                    .foregroundStyle(.white.opacity(0.9))
                Text(title)
                    .font(.system(size: 11))
                    .foregroundStyle(.white)
                Spacer()
                if let shortcut {
                    Text(shortcut)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 5).fill(hover ? Color.white.opacity(0.12) : Color.clear))
            .scaleEffect(hover ? 1.02 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: hover)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }


}

// MARK: - TASK 3A: Keyboard Lock header button
private struct KeyboardLockButton: View {
    @ObservedObject var store = Store.shared
    @ObservedObject var mgr = KeyboardLockManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        Button {
            mgr.toggle()
        } label: {
            Image(systemName: "keyboard")
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 32, height: 32)
                .foregroundStyle(mgr.isLocked ? Color.black : Color.white.opacity(0.85))
                .background {
                    Circle()
                        .fill(mgr.isLocked ? Color.orange : Color.white.opacity(0.08))
                        .scaleEffect(mgr.isLocked && pulse ? 1.12 : 1.0)
                        .animation(
                            mgr.isLocked && !reduceMotion
                                ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true)
                                : .default,
                            value: pulse
                        )
                }
                .overlay { Circle().strokeBorder(.white.opacity(0.10), lineWidth: 0.8) }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(mgr.isLocked ? "Click to unlock keyboard" : "Lock keyboard (blocks all key input)")
        .onChange(of: mgr.isLocked) { _, locked in
            pulse = locked
        }
        .onAppear { pulse = mgr.isLocked }
    }
}

// MARK: - TASK 3B: Hide Island (lock) header button
private struct HideIslandButton: View {
    @ObservedObject var store = Store.shared

    var body: some View {
        Button {
            withAnimation(.inertiaLiquid(speed: Store.shared.animSpeed, reduceMotion: false)) {
                store.mode = .collapsed
            }
            // Small delay so the collapse animation starts before hiding.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                store.islandHidden = true
            }
        } label: {
            Image(systemName: "lock.fill")
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 32, height: 32)
                .foregroundStyle(.white.opacity(0.85))
                .background { Circle().fill(.white.opacity(0.08)) }
                .overlay { Circle().strokeBorder(.white.opacity(0.10), lineWidth: 0.8) }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Hide island (Ctrl+Opt+N or click notch area to restore)")
    }
}
