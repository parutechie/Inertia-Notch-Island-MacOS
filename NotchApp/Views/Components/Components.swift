import SwiftUI
import AppKit

// MARK: - Island layout
// One source of truth for the open island. Every tab, the header, the divider and
// the footer use these values so their edges line up exactly.
enum IslandLayout {
    /// Horizontal inset from the panel edge to the content on both sides.
    static let contentInset: CGFloat = 18
    /// Vertical rhythm used around the header divider and between content sections.
    static let verticalSpacing: CGFloat = 12
    /// The open island is deliberately short and wide (more rectangle, less tall).
    static let openPanelHeight: CGFloat = 330
    static let openPanelDefaultWidth: CGFloat = 668
    static let openPanelMinWidth: CGFloat = 600
    static let openPanelMaxWidth: CGFloat = 720
    /// Hovering the collapsed music island expands it into this now-playing card.
    static let hoverWidth: CGFloat = 392
    static let hoverHeight: CGFloat = 88
    /// Extra height that makes the collapsed music island feel like a wing bar.
    static let collapsedMusicExtraHeight: CGFloat = 9
    /// Minimal horizontal padding on each side of the collapsed notch when idle (no music/focus/privacy).
    /// UI-1: tight rectangle padding.
    static let collapsedMinPadH: CGFloat = 8
    /// Collapsed wing content: inset from the island edge, gap before the notch,
    /// and the spacing between emoji/artwork/privacy items.
    static let collapsedWingInset: CGFloat = 11
    static let collapsedWingNotchGap: CGFloat = 8
    static let collapsedWingSpacing: CGFloat = 8
    static let collapsedArtworkSize: CGFloat = 28
    static let collapsedFocusIconWidth: CGFloat = 11
    static let collapsedEmojiWidth: CGFloat = 54
    // UI-6: Lottie animation frame in the left wing. Edit this one number to resize.
    // The cat composition is 280×200; .scaleAspectFit letterboxes it inside this square.
    static let collapsedLottieSize: CGFloat = 60
    /// Small app-icon privacy badges shown for mic/camera/screen activity.
    static let privacyIconSize: CGFloat = 18
    static let privacyIconSpacing: CGFloat = 6

    /// Total width of the privacy app icons plus their spacing.
    static func privacyIndicatorsWidth(_ count: Int) -> CGFloat {
        guard count > 0 else { return 0 }
        return CGFloat(count) * privacyIconSize + CGFloat(count - 1) * privacyIconSpacing
    }

    /// Width required by the collapsed left wing, including its notch clearance.
    static func collapsedLeftWidth(emoji: Bool, music: Bool, focus: Bool,
                                   privacyCount: Int) -> CGFloat {
        var content: CGFloat = 0
        var items = 0
        if emoji { content += collapsedEmojiWidth; items += 1 }
        if music { content += collapsedArtworkSize; items += 1 }
        else if focus { content += collapsedFocusIconWidth; items += 1 }
        if privacyCount > 0 {
            content += privacyIndicatorsWidth(privacyCount)
            items += 1
        }
        guard items > 0 else { return 0 }
        return collapsedWingInset + content
            + CGFloat(items - 1) * collapsedWingSpacing
            + collapsedWingNotchGap
    }
    /// Shared geometry for the "..." menu so its rows, padding and grid edge line up.
    static let menuWidth: CGFloat = 196
    static let menuRowHeight: CGFloat = 28
    static let menuIconWidth: CGFloat = 22
    static let menuRowSpacing: CGFloat = 6
    static let menuPadding: CGFloat = 6
    static let menuCornerRadius: CGFloat = 16
    /// Shared top inset for the Launcher grid and the trailing menu.
    static let launcherTopInset: CGFloat = 6

    /// Fixed height of the open panel header bar.
    static let headerHeight: CGFloat = 44
    /// Top padding below the physical notch bottom edge so header content never
    /// draws under the cutout.
    static let headerTopInset: CGFloat = 8

    // MARK: - Hover music card layout (TASK 4)
    static let keyboardLockMaxMinutes: Int = 10
    static let hoverPadH: CGFloat = 22
    static let hoverPadTop: CGFloat = 10        // gap below physical notch bottom
    static let hoverPadBottom: CGFloat = 18
    static let hoverArtworkSize: CGFloat = 52
    static let hoverGapArtworkText: CGFloat = 14
    static let hoverGapTextControls: CGFloat = 18
    static let hoverControlSpacing: CGFloat = 10
    static let hoverControlSize: CGFloat = 32   // rewind/forward; play/pause = 40
    
    // UI-2: Expanded hover card with album art (shows on music hover)
    static let hoverExpandedArtworkSize: CGFloat = 100
    static let hoverExpandedArtworkGap: CGFloat = 12
    static let hoverDurationHeight: CGFloat = 18
    static let hoverDurationGap: CGFloat = 8
    
    // UI-2: Volume control row (expands on hover over speaker icon)
    static let hoverVolumeRowHeight: CGFloat = 28
    static let hoverVolumeGapAbove: CGFloat = 12
    static let hoverVolumeIconSize: CGFloat = 14
    static let hoverVolumeBarHeight: CGFloat = 4
    static let hoverVolumeThumbSize: CGFloat = 11
    static let hoverVolumePercentageWidth: CGFloat = 32

    // MARK: - UI-5c: Hover music card constants (fit exactly 3 rows: header, transport, volume)
    static let hc5HeaderHeight: CGFloat  = 52   // artwork height = row height
    static let hc5ProgressHeight: CGFloat = 4   // kept for reference, not used in hover card
    static let hc5ProgressHit: CGFloat   = 24   // kept for reference
    static let hc5TimeHeight: CGFloat    = 16   // kept for reference
    static let hc5ControlsHeight: CGFloat = 44  // tallest button (play/pause)
    static let hc5VolumeHeight: CGFloat  = 24   // slider hit area
    static let hc5RowGap: CGFloat        = 12   // uniform gap between rows
    static let hc5BottomPad: CGFloat     = 18   // below volume row
    static let hc5ArtworkSize: CGFloat   = 52   // artwork square
    static let hc5ArtworkCorner: CGFloat = 8
    static let hc5ThumbSize: CGFloat     = 14   // volume knob

    /// UI-5c: height for the 3-row hover card (header + transport + volume).
    static func hoverCardHeight(notchHeight: CGFloat) -> CGFloat {
        let rows = hc5HeaderHeight + hc5ControlsHeight + hc5VolumeHeight
        let gaps = hc5RowGap * 2   // 2 gaps between 3 rows
        return notchHeight + hoverPadTop + rows + gaps + hc5BottomPad
    }

    /// BUG 1 fix: total top padding from panel y=0 to the first pixel of header
    /// content. This is the notch height plus exactly 6 pt — nothing more.
    /// The background fills the whole island shape from y=0; there is no separate
    /// rectangle above the header.
    static func headerTopInset(notchHeight: CGFloat) -> CGFloat {
        notchHeight + 6
    }

    /// TASK 2: Height of the intro animation content area below the notch.
    static let introContentHeight: CGFloat = 210
    /// Size of each icon-only tab button in the header capsule.
    static let tabIconSize: CGFloat = 32
    /// Spacing between icon-only tab buttons in the header capsule.
    static let tabIconSpacing: CGFloat = 4
    /// Size of the right-side collapse chevron button.
    static let collapseButtonSize: CGFloat = 36
    /// Height the island expands downward for a live-status HUD below the notch.
    static let hudExpandedHeight: CGFloat = 116
}

// MARK: - Animation
extension Animation {
    /// The one spring used for island morphs, tab changes, menus and Launcher items.
    /// `animSpeed` is the user's speed multiplier (higher = faster).
    static func inertiaLiquid(speed: Double, reduceMotion: Bool) -> Animation {
        if reduceMotion { return .easeInOut(duration: 0.18) }
        return .spring(response: 0.42 / max(speed, 0.1), dampingFraction: 0.72)
    }
}

/// Pressed controls shrink slightly with the same liquid spring.
struct InertiaPressStyle: ButtonStyle {
    var speed: Double = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.94 : 1)
            .animation(.inertiaLiquid(speed: speed, reduceMotion: reduceMotion),
                       value: configuration.isPressed)
    }
}

// MARK: - Shared glass background
/// Translucent, matte glass: a dark thin-material wash with a soft noise grain,
/// a subtle per-tab tint blended over the material, and a diagonal top-edge
/// sheen whose strength is controlled by `gloss`.
// UI-7: exposed internally so the Settings window can reuse the same grain.
enum InertiaNoiseTexture {
    static let image: NSImage = {
        let dimension = 96
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: dimension,
            pixelsHigh: dimension,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return NSImage(size: NSSize(width: dimension, height: dimension)) }

        var seed: UInt32 = 0x1A2B3C4D
        for y in 0..<dimension {
            for x in 0..<dimension {
                seed = seed &* 1664525 &+ 1013904223
                let value = CGFloat(seed >> 24) / 255
                let alpha = value > 0.56 ? (value - 0.56) * 0.48 : 0
                rep.setColor(NSColor(white: 1, alpha: alpha), atX: x, y: y)
            }
        }

        let image = NSImage(size: NSSize(width: dimension, height: dimension))
        image.addRepresentation(rep)
        return image
    }()
}

// MARK: - Island background (per-tab tint with soft glow blobs)
/// Near-black opaque base (BUG 3 fix: 0.94 opacity so nothing behind shows through),
/// with two soft blurred radial glow blobs in the lower corners whose hue follows
/// the active tab tint (capped at 0.25 opacity), a matte noise grain, and a faint
/// top-edge highlight. The glows are clipped to the island shape via the caller's
/// clipShape.
struct InertiaIslandBackground: View {
    var tint: Color = .clear
    // FIX 4: fully opaque near-black base; no material so the desktop never bleeds through.
    var glowOpacity: Double = 0.25
    var accentOpacity: Double = 0.14
    var noiseOpacity: Double = 0.04

    private var accent: Color {
        Color(red: 0.85, green: 0.45, blue: 0.95)
    }

    var body: some View {
        ZStack(alignment: .top) {
            // 1. FIX 4: fully opaque base — no material, no see-through.
            Color(white: 0.04)

            // 2. Soft blurred radial glow blobs (opacity ≤ 0.25), clipped by caller's clipShape.
            ZStack {
                Circle()
                    .fill(tint.opacity(glowOpacity))
                    .blur(radius: 70, opaque: false)
                    .frame(width: 220, height: 220)
                    .alignmentGuide(.bottom) { d in d[.bottom] - 30 }
                    .alignmentGuide(.leading) { d in d[.leading] - 30 }

                Circle()
                    .fill(accent.opacity(accentOpacity))
                    .blur(radius: 80, opaque: false)
                    .frame(width: 260, height: 260)
                    .alignmentGuide(.bottom) { d in d[.bottom] - 20 }
                    .alignmentGuide(.trailing) { d in d[.trailing] - 20 }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)

            // 3. Faint noise grain (≤ 0.04).
            Image(nsImage: InertiaNoiseTexture.image)
                .resizable(resizingMode: .tile)
                .opacity(noiseOpacity)
                .blendMode(.plusLighter)
        }
    }
}

struct InertiaGlassLayer: View {
    var tint: Color = .clear
    var tintOpacity: Double = 0.20
    var materialOpacity: Double = 0.50
    var noiseOpacity: Double = 0.06
    // FIX 2B: smooth diagonal sheen only — no hard-edged highlight strip.
    var highlightOpacity: Double = 0.10
    var gloss: Double = 0.5

    var body: some View {
        ZStack(alignment: .top) {
            // Dark translucent base so the background stays visibly see-through.
            Color.black.opacity(0.30)

            // Frosted material wash.
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(materialOpacity)

            // Per-tab tint blended softly over the material.
            tint.opacity(tintOpacity)

            // Soft matte noise grain.
            Image(nsImage: InertiaNoiseTexture.image)
                .resizable(resizingMode: .tile)
                .opacity(noiseOpacity)
                .blendMode(.plusLighter)

            // FIX 2B: ONE smooth top-leading→bottom-trailing gradient.
            // Stops: white 0.10 at 0.0 → white 0.03 at 0.5 → clear at 1.0.
            // No Rectangle, no two stops at the same location.
            LinearGradient(
                stops: [
                    .init(color: .white.opacity(highlightOpacity * gloss), location: 0.0),
                    .init(color: .white.opacity(0.03 * gloss),             location: 0.5),
                    .init(color: .clear,                                    location: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

struct InertiaGlassBackground: ViewModifier {
    var cornerRadius: CGFloat
    var showsStroke: Bool
    var tint: Color = .clear
    var gloss: Double = 0.5
    var materialOpacity: Double = 0.45
    var noiseOpacity: Double = 0.06
    var highlightOpacity: Double = 0.18

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content.background {
            InertiaGlassLayer(tint: tint,
                              materialOpacity: materialOpacity,
                              noiseOpacity: noiseOpacity,
                              highlightOpacity: highlightOpacity,
                              gloss: gloss)
                .clipShape(shape)
                .overlay {
                    if showsStroke {
                        shape.strokeBorder(
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0),
                                    .init(color: .white.opacity(0.12), location: 0.14),
                                    .init(color: .white.opacity(0.06), location: 1)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.8
                        )
                    }
                }
        }
    }
}

extension View {
    func inertiaGlassBackground(cornerRadius: CGFloat = 16,
                                showsStroke: Bool = true,
                                tint: Color = .clear,
                                gloss: Double = 0.5,
                                materialOpacity: Double = 0.45,
                                noiseOpacity: Double = 0.06,
                                highlightOpacity: Double = 0.18) -> some View {
        modifier(InertiaGlassBackground(cornerRadius: cornerRadius,
                                        showsStroke: showsStroke,
                                        tint: tint,
                                        gloss: gloss,
                                        materialOpacity: materialOpacity,
                                        noiseOpacity: noiseOpacity,
                                        highlightOpacity: highlightOpacity))
    }
}

// MARK: - Glass surface
struct Glass: ViewModifier {
    var radius: CGFloat
    func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(.white.opacity(0.07)))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(
                LinearGradient(colors: [.white.opacity(0.30), .white.opacity(0.04)],
                               startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.6))
    }
}
extension View { func glass(_ r: CGFloat = 12) -> some View { modifier(Glass(radius: r)) } }

// MARK: - Buttons
// NOTE: every button label has an explicit contentShape. A `.plain` SwiftUI button only
// reacts on pixels that are actually drawn, so hollow shapes (like an empty checkbox ring)
// ignored clicks in their middle. That was the "can't tick a task" bug.
struct PillButton: View {
    let title: String; var tint: Color?; let action: () -> Void
    init(_ title: String, tint: Color? = nil, action: @escaping () -> Void) {
        self.title = title; self.tint = tint; self.action = action
    }
    var body: some View {
        Button(action: action) {
            Text(title).font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .foregroundStyle(tint == nil ? Color.white : Color.black)
                .background(Capsule().fill(tint ?? Color.white.opacity(0.10)))
                .overlay(Capsule().strokeBorder(.white.opacity(tint == nil ? 0.2 : 0), lineWidth: 0.6))
                .contentShape(Capsule())
        }.buttonStyle(.plain)
    }
}

struct Chip: View {
    let text: String; var on = false; var tint: Color = .white; let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(text).font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 9).padding(.vertical, 5)
                .foregroundStyle(on ? Color.black : Color.white.opacity(0.8))
                .background(Capsule().fill(on ? tint : Color.white.opacity(0.08)))
                .overlay(Capsule().strokeBorder(.white.opacity(on ? 0 : 0.15), lineWidth: 0.6))
                .contentShape(Capsule())
        }.buttonStyle(.plain)
    }
}

struct IconButton: View {
    let symbol: String
    var size: CGFloat = 26
    var tint: Color? = nil
    var danger = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(danger ? Color.red.opacity(0.9) : (tint ?? Color.white.opacity(0.85)))
                .frame(width: size, height: size)
                .glass(size / 2)
                .contentShape(Circle())
        }.buttonStyle(.plain)
    }
}

struct MiniStepper: View {
    let label: String; @Binding var value: Int; let range: ClosedRange<Int>; var step = 1
    var body: some View {
        HStack(spacing: 8) {
            Text(label).font(.system(size: 12)).foregroundStyle(.white.opacity(0.6))
            Spacer()
            Button { value = max(range.lowerBound, value - step) } label: {
                Image(systemName: "minus").font(.system(size: 10, weight: .bold)).frame(width: 22, height: 22).glass(11)
                    .contentShape(Circle())
            }.buttonStyle(.plain)
            Text("\(value) min").font(.system(size: 12, weight: .semibold, design: .monospaced)).frame(width: 60)
            Button { value = min(range.upperBound, value + step) } label: {
                Image(systemName: "plus").font(.system(size: 10, weight: .bold)).frame(width: 22, height: 22).glass(11)
                    .contentShape(Circle())
            }.buttonStyle(.plain)
        }
    }
}

func prioColor(_ p: Int) -> Color {
    [Color(red: 0.35, green: 0.95, blue: 0.80), Color(red: 1.0, green: 0.78, blue: 0.40), Color(red: 1.0, green: 0.42, blue: 0.52)][min(max(p, 0), 2)]
}

func mmss(_ s: Double) -> String {
    let t = max(Int(s), 0)
    return String(format: "%d:%02d", t / 60, t % 60)
}

// MARK: - Wheel picker (drag, scroll wheel, or tap the neighbours)
struct WheelPicker: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    var tint: Color = .white
    var step = 1
    var format: (Int) -> String = { String(format: "%02d", $0) }
    @State var hovering = false
    @State var dragSteps = 0
    @State var scrollAcc: CGFloat = 0
    @State var monitor: Any? = nil

    private func wrap(_ v: Int) -> Int {
        let n = range.count
        return (((v - range.lowerBound) % n) + n) % n + range.lowerBound
    }

    var body: some View {
        VStack(spacing: 0) {
            neighbour(-1)
            Text(format(value))
                .font(.system(size: 36, weight: .semibold, design: .rounded)).monospacedDigit()
                .foregroundStyle(.white).frame(width: 64, height: 42)
                .contentTransition(.numericText())
            neighbour(1)
        }
        .animation(.snappy(duration: 0.18), value: value)
        .padding(.vertical, 2)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(hovering ? 0.11 : 0.06)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(hovering ? tint.opacity(0.7) : Color.white.opacity(0.12), lineWidth: 0.8))
        .onHover { hovering = $0 }
        .simultaneousGesture(
            DragGesture(minimumDistance: 6)
                .onChanged { g in
                    let s = Int(-g.translation.height / 14)
                    if s != dragSteps { value = wrap(value + (s - dragSteps) * step); dragSteps = s }
                }
                .onEnded { _ in dragSteps = 0 }
        )
        .onAppear {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { e in
                guard hovering else { return e }
                let inv: CGFloat = e.isDirectionInvertedFromDevice ? -1 : 1
                scrollAcc += e.scrollingDeltaY * inv * (e.hasPreciseScrollingDeltas ? 1.0 / 9.0 : 1.0)
                let n = Int(scrollAcc)
                if n != 0 { value = wrap(value + n * step); scrollAcc -= CGFloat(n) }
                return nil
            }
        }
        .onDisappear { if let m = monitor { NSEvent.removeMonitor(m); monitor = nil } }
    }

    private func neighbour(_ dir: Int) -> some View {
        Button { value = wrap(value + dir * step) } label: {
            Text(format(wrap(value + dir * step)))
                .font(.system(size: 14, weight: .medium, design: .rounded)).monospacedDigit()
                .foregroundStyle(.white.opacity(0.28)).frame(width: 64, height: 18)
                .contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
}

// MARK: - Marquee (scrolls long text, stays still when it fits)
private struct MarqueeW: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

struct Marquee: View {
    let text: String
    var size: CGFloat = 14
    var weight: Font.Weight = .semibold
    var color: Color = .white
    var speed: Double = 32
    @State var textW: CGFloat = 0

    private var label: some View {
        Text(text).font(.system(size: size, weight: weight)).foregroundStyle(color).lineLimit(1).fixedSize()
    }

    var body: some View {
        GeometryReader { geo in
            let overflow = textW > geo.size.width + 1
            let gap: CGFloat = 40
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !overflow)) { tl in
                let cycle = Double(textW + gap)
                let shift: CGFloat = overflow
                    ? CGFloat((tl.date.timeIntervalSinceReferenceDate * speed).truncatingRemainder(dividingBy: cycle))
                    : 0
                HStack(spacing: gap) {
                    label
                    if overflow { label }
                }
                .offset(x: -shift)
                .frame(width: geo.size.width, alignment: .leading)
            }
            .clipped()
            .mask(LinearGradient(stops: [
                .init(color: overflow ? .clear : .black, location: 0),
                .init(color: .black, location: 0.001 + (overflow ? 0.05 : 0)),
                .init(color: .black, location: overflow ? 0.93 : 1),
                .init(color: overflow ? .clear : .black, location: 1)
            ], startPoint: .leading, endPoint: .trailing))
        }
        .frame(height: size * 1.4)
        .overlay(alignment: .leading) {
            label.hidden().background(GeometryReader { g in
                Color.clear.preference(key: MarqueeW.self, value: g.size.width)
            })
        }
        .onPreferenceChange(MarqueeW.self) { textW = $0 }
        .id(text)
    }
}

// MARK: - Equalizer bars
struct Equalizer: View {
    var active: Bool
    var color: Color = .white
    var bars = 4
    var maxH: CGFloat = 14
    var barW: CGFloat = 3
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !active)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: max(2, barW * 0.6)) {
                ForEach(0..<bars, id: \.self) { i in
                    let k = abs(sin(t * (2.6 + Double(i) * 0.7) + Double(i) * 1.3))
                    Capsule().fill(color)
                        .frame(width: barW, height: active ? 3 + (maxH - 3) * CGFloat(k) : 3)
                }
            }
            .frame(height: maxH)
        }
    }
}

// MARK: - Volume slider (UI-2: shows slider on hover over speaker icon)
struct VolumeSliderControl: View {
    @ObservedObject private var audio = AudioManager.shared
    @State private var dragValue: Float? = nil
    @State private var scrollAcc: CGFloat = 0
    @State private var monitor: Any? = nil
    @State private var thumbScale: CGFloat = 1.0
    @State private var isHovering = false
    let accentColor: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var liquid: Animation {
        .inertiaLiquid(speed: 1, reduceMotion: reduceMotion)
    }

    private var volume: Float {
        dragValue ?? audio.outputVolume
    }

    private var volumePercent: Int {
        Int(round(Float(volume) * 100))
    }

    private var volumeIcon: String {
        if audio.isMuted { return "speaker.slash" }
        let level = audio.outputVolume
        if level > 0.66 { return "speaker.wave.3" }
        if level > 0.33 { return "speaker.wave.2" }
        if level > 0 { return "speaker.wave.1" }
        return "speaker.slash"
    }

    var body: some View {
        HStack(spacing: 10) {
            // UI-2: Speaker icon button (toggles mute)
            Button {
                let newMuted = !audio.isMuted
                SystemOutputVolume.setMuted(newMuted)
                audio.isMuted = newMuted
            } label: {
                Image(systemName: volumeIcon)
                    .font(.system(size: IslandLayout.hoverVolumeIconSize, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Toggle mute")
            .onHover { hovering in
                isHovering = hovering
            }

            // UI-2: Slider track (shows on hover)
            if isHovering {
                VolumeSliderTrack(volume: volume, thumbScale: $thumbScale, accentColor: accentColor, 
                                onChanged: { progress in
                    dragValue = progress
                }, onEnded: {
                    if let d = dragValue {
                        SystemOutputVolume.setVolume(Double(d))
                        audio.outputVolume = d
                        dragValue = nil
                    }
                })
                .frame(maxWidth: .infinity)
                .transition(.scale(scale: 0.8).combined(with: .opacity))

                // UI-2: Percentage label (fixed width to prevent jitter)
                Text("\(volumePercent)%")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(width: IslandLayout.hoverVolumePercentageWidth, alignment: .trailing)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
            
            Spacer()
        }
        .frame(height: IslandLayout.hoverVolumeRowHeight)
        .animation(liquid, value: isHovering)
        .animation(liquid, value: thumbScale)
        .onAppear {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { e in
                guard isHovering else { return e }
                let inv: CGFloat = e.isDirectionInvertedFromDevice ? -1 : 1
                scrollAcc += e.scrollingDeltaY * inv * (e.hasPreciseScrollingDeltas ? 0.01 : 0.05)
                let delta = Float(scrollAcc)
                if abs(delta) > 0.001 {
                    let newVol = max(0, min(1, audio.outputVolume + delta))
                    SystemOutputVolume.setVolume(Double(newVol))
                    audio.outputVolume = newVol
                    scrollAcc = 0
                }
                return nil
            }
        }
        .onDisappear {
            if let m = monitor { NSEvent.removeMonitor(m) }
        }
    }
}

// MARK: - Volume slider track (UI-2 helper)
private struct VolumeSliderTrack: View {
    let volume: Float
    @Binding var thumbScale: CGFloat
    let accentColor: Color
    let onChanged: (Float) -> Void
    let onEnded: () -> Void
    @State private var isDragging = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Background track
                Capsule()
                    .fill(Color.white.opacity(0.15))
                    .frame(height: IslandLayout.hoverVolumeBarHeight)
                
                // Filled track
                Capsule()
                    .fill(accentColor)
                    .frame(width: CGFloat(volume) * geo.size.width,
                           height: IslandLayout.hoverVolumeBarHeight)
                
                // Draggable thumb
                Circle()
                    .fill(.white)
                    .frame(width: IslandLayout.hoverVolumeThumbSize, height: IslandLayout.hoverVolumeThumbSize)
                    .scaleEffect(thumbScale)
                    .offset(x: CGFloat(volume) * (geo.size.width - IslandLayout.hoverVolumeThumbSize) + IslandLayout.hoverVolumeThumbSize / 2)
            }
            .frame(height: IslandLayout.hoverVolumeRowHeight)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        if !isDragging {
                            isDragging = true
                            thumbScale = 1.15
                        }
                        let progress = max(0, min(1, g.location.x / geo.size.width))
                        onChanged(Float(progress))
                    }
                    .onEnded { _ in
                        isDragging = false
                        thumbScale = 1.0
                        onEnded()
                    }
            )
        }
        .frame(height: IslandLayout.hoverVolumeRowHeight)
    }
}


// MARK: - App icons (browser / player logos)
enum AppIcons {
    private static var cache: [String: NSImage] = [:]
    static func icon(_ bundleID: String?) -> NSImage? {
        guard let bundleID = bundleID else { return nil }
        if let c = cache[bundleID] { return c }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        let img = NSWorkspace.shared.icon(forFile: url.path)
        cache[bundleID] = img
        return img
    }
}

/// Album artwork thumbnail used by the collapsed island and the hover card.
/// Pass `corner: nil` for a circle, or a radius for a rounded square.
struct ArtworkThumb: View {
    let url: URL?
    var size: CGFloat
    var corner: CGFloat? = nil

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().interpolation(.high).scaledToFill()
                    } else {
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: corner ?? size / 2, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: corner ?? size / 2, style: .continuous)
                .strokeBorder(.white.opacity(0.16), lineWidth: 0.6)
        )
    }

    private var fallback: some View {
        ZStack {
            LinearGradient(colors: [IslandTab.music.tint.opacity(0.85),
                                    Color(red: 0.55, green: 0.40, blue: 1.0).opacity(0.8)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: "music.note")
                .font(.system(size: size * 0.38, weight: .bold))
                .foregroundStyle(.white.opacity(0.92))
        }
    }
}

struct AppIconView: View {
    let bundleID: String?
    var size: CGFloat = 18
    var fallbackSystemName = "music.note"
    var fallbackColor: Color = .primary
    var body: some View {
        if let img = AppIcons.icon(bundleID) {
            Image(nsImage: img).resizable().interpolation(.high).frame(width: size, height: size)
        } else {
            Image(systemName: fallbackSystemName)
                .font(.system(size: size * 0.6, weight: .semibold))
                .foregroundStyle(fallbackColor)
                .frame(width: size, height: size)
        }
    }
}
