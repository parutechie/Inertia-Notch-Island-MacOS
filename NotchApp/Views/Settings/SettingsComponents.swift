import SwiftUI
import AppKit

// UI-7: Inertia Glass Settings — shared visual language.
// Every settings page uses these atoms so spacing, motion and controls stay identical.

// MARK: - Accent color per page (UI-7)

extension SettingsPage {
    var accent: Color {
        switch self {
        case .general:     return Color(red: 0.29, green: 0.56, blue: 1.00)
        case .focus:       return Color(red: 0.42, green: 0.52, blue: 0.95)
        case .sound:       return Color(red: 0.22, green: 0.82, blue: 0.95)
        case .brightness:  return Color(red: 1.00, green: 0.60, blue: 0.20)
        case .battery:     return Color(red: 0.28, green: 0.90, blue: 0.45)
        case .audio:       return Color(red: 0.72, green: 0.38, blue: 1.00)
        case .music:       return Color(red: 1.00, green: 0.38, blue: 0.56)
        case .calendar:    return Color(red: 1.00, green: 0.60, blue: 0.20)
        case .permissions: return Color(red: 1.00, green: 0.50, blue: 0.20)
        case .about:       return Color(red: 0.55, green: 0.55, blue: 0.60)
        }
    }
}

// MARK: - SettingsIconTile (UI-7)
/// Squircle icon tile in the page accent, with a soft inner highlight and glow.
struct SettingsIconTile: View {
    let icon: String
    var accent: Color = .blue
    var size: CGFloat = 28
    var radius: CGFloat = 8

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(LinearGradient(colors: [accent, accent.opacity(0.62)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(RadialGradient(colors: [.white.opacity(0.32), .clear],
                                     center: .topLeading, startRadius: 0, endRadius: size * 0.9))
                .blendMode(.plusLighter)
            Image(systemName: icon)
                .font(.system(size: size * 0.44, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(.white.opacity(0.18), lineWidth: 0.7)
        )
        .shadow(color: accent.opacity(0.30), radius: size * 0.18, y: size * 0.06)
    }
}

// MARK: - InertiaToggleStyle (UI-7)
/// Wide capsule toggle. Off is dark glass; on is a luminous accent gradient.
/// The knob stretches while pressed, then springs back with inertiaLiquid.
struct InertiaToggleStyle: ToggleStyle {
    var accent: Color = .blue

    func makeBody(configuration: Configuration) -> some View {
        TogglePill(isOn: configuration.isOn, accent: accent) {
            configuration.isOn.toggle()
        }
    }
}

private struct TogglePill: View {
    let isOn: Bool
    let accent: Color
    let onToggle: () -> Void
    @State private var pressing = false
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var liquid: Animation {
        .inertiaLiquid(speed: 1.1, reduceMotion: reduceMotion)
    }

    private var knobWidth: CGFloat {
        pressing && !reduceMotion ? 25 : 21
    }

    var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule()
                .fill(isOn
                      ? AnyShapeStyle(LinearGradient(
                            colors: [accent.opacity(0.98), accent.opacity(0.72)],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                      : AnyShapeStyle(LinearGradient(
                            colors: [.white.opacity(0.12), .white.opacity(0.055)],
                            startPoint: .top, endPoint: .bottom)))
                .overlay(
                    Capsule()
                        .fill(LinearGradient(colors: [.white.opacity(isOn ? 0.22 : 0.08), .clear],
                                             startPoint: .top, endPoint: .bottom))
                        .padding(1)
                        .blendMode(.plusLighter)
                )
                .overlay(Capsule().strokeBorder(.white.opacity(isOn ? 0.26 : 0.10), lineWidth: 0.7))
                .frame(width: 52, height: 30)
                .shadow(color: isOn ? accent.opacity(hovering ? 0.62 : 0.48) : .clear,
                        radius: isOn ? (hovering ? 12 : 9) : 0, y: 2)

            Capsule()
                .fill(LinearGradient(colors: [.white, Color(white: 0.94)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: knobWidth, height: 22)
                .shadow(color: .black.opacity(0.34), radius: 3, y: 1)
                .padding(.horizontal, 4)
        }
        .frame(width: 52, height: 30)
        .contentShape(Capsule())
        .onHover { hovering = $0 }
        .scaleEffect(pressing && !reduceMotion ? 0.97 : 1)
        .animation(liquid, value: isOn)
        .animation(liquid, value: pressing)
        .animation(liquid, value: hovering)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !pressing { withAnimation(liquid) { pressing = true } }
                }
                .onEnded { _ in
                    withAnimation(liquid) { pressing = false }
                    onToggle()
                }
        )
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - InertiaSlider (UI-7)
/// 6pt capsule track, accent gradient fill, glow near the knob, a few faint snap
/// ticks, and a floating value pill while dragging. Knob grows on hover or drag.
struct InertiaSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double>
    var step: Double = 1
    var accent: Color = .blue
    /// Fixed trailing label, kept in monospaced digits (e.g. "284px").
    var label: String = ""
    var formatValue: ((Double) -> String)? = nil

    @State private var isDragging = false
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var liquid: Animation {
        .inertiaLiquid(speed: 1, reduceMotion: reduceMotion)
    }

    private var progress: Double {
        guard range.upperBound > range.lowerBound else { return 0 }
        return min(max((value - range.lowerBound) / (range.upperBound - range.lowerBound), 0), 1)
    }

    private var displayValue: String {
        formatValue?(value) ?? (label.isEmpty ? String(format: "%.0f", value) : label)
    }

    var body: some View {
        HStack(spacing: 12) {
            GeometryReader { geo in
                let width = max(geo.size.width, 1)
                let knobCenter = 9 + (width - 18) * CGFloat(progress)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.10))
                        .frame(height: 6)
                        .offset(y: 4)

                    // A handful of faint snap ticks instead of a dotted ruler.
                    HStack(spacing: 0) {
                        ForEach(0..<5, id: \.self) { index in
                            Circle()
                                .fill(Color.white.opacity(0.14))
                                .frame(width: 2.5, height: 2.5)
                            if index < 4 { Spacer(minLength: 0) }
                        }
                    }
                    .padding(.horizontal, 2)
                    .offset(y: 4)

                    Capsule()
                        .fill(LinearGradient(
                            colors: [accent.opacity(0.78), accent],
                            startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(6, knobCenter), height: 6)
                        .offset(y: 4)
                        .shadow(color: accent.opacity(isDragging ? 0.55 : 0.28),
                                radius: isDragging ? 9 : 4, y: 0)

                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [.white, Color(white: 0.92)],
                                                 startPoint: .top, endPoint: .bottom))
                            .frame(width: 18, height: 18)
                            .shadow(color: accent.opacity(isDragging ? 0.65 : 0.35),
                                    radius: isDragging ? 11 : 5, y: 1)
                            .scaleEffect((hovering || isDragging) && !reduceMotion ? 1.15 : 1)

                        if isDragging {
                            Text(displayValue)
                                .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(accent))
                                .overlay(Capsule().strokeBorder(.white.opacity(0.22), lineWidth: 0.6))
                                .shadow(color: accent.opacity(0.5), radius: 8, y: 2)
                                .fixedSize()
                                .offset(y: -30)
                                .transition(.scale(scale: 0.72).combined(with: .opacity))
                        }
                    }
                    .position(x: knobCenter, y: 26)
                }
                .frame(height: 44)
                .contentShape(Rectangle())
                .onHover { hovering = $0 }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { drag in
                            if !isDragging {
                                withAnimation(liquid) { isDragging = true }
                            }
                            let clamped = min(max(drag.location.x / width, 0), 1)
                            let raw = range.lowerBound + Double(clamped) * (range.upperBound - range.lowerBound)
                            if step > 0 {
                                let snapped = (raw / step).rounded() * step
                                value = min(max(snapped, range.lowerBound), range.upperBound)
                            } else {
                                value = min(max(raw, range.lowerBound), range.upperBound)
                            }
                        }
                        .onEnded { _ in
                            withAnimation(liquid) { isDragging = false }
                        }
                )
                .animation(liquid, value: isDragging)
                .animation(liquid, value: hovering)
            }
            .frame(height: 44)

            if !label.isEmpty || formatValue != nil {
                Text(displayValue)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(minWidth: 48, alignment: .trailing)
                    .contentTransition(.numericText())
            }
        }
        .accessibilityValue(displayValue)
    }
}

// MARK: - SettingsCard (UI-7)
/// 20pt glass card with a 6% white fill, accent corner wash, gradient hairline
/// border and a soft inner shadow.
struct SettingsCard<Content: View>: View {
    var accent: Color = .blue
    @ViewBuilder var content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 10)
            .clipShape(shape)
            .background {
                ZStack {
                    shape.fill(Color.white.opacity(0.06))
                    RadialGradient(colors: [accent.opacity(0.075), .clear],
                                   center: .topLeading, startRadius: 0, endRadius: 280)
                        .clipShape(shape)
                    Image(nsImage: InertiaNoiseTexture.image)
                        .resizable(resizingMode: .tile)
                        .opacity(0.022)
                        .blendMode(.plusLighter)
                        .clipShape(shape)
                    shape.stroke(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.24), location: 0),
                                .init(color: .white.opacity(0.08), location: 0.48),
                                .init(color: .white.opacity(0.03), location: 1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
                    shape.stroke(Color.black.opacity(0.30), lineWidth: 1)
                        .blur(radius: 2)
                        .clipShape(shape)
                }
            }
            .shadow(color: .black.opacity(0.30), radius: 18, y: 9)
    }
}

// MARK: - SettingsDivider (UI-7)

struct SettingsDivider: View {
    var inset: CGFloat = 18

    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.07))
            .frame(height: 0.7)
            .padding(.leading, inset)
    }
}

// MARK: - SettingsRow (UI-7)
/// 56pt row whose background brightens by 3% on hover.
struct SettingsRow<Content: View>: View {
    var minHeight: CGFloat = 56
    @ViewBuilder var content: Content

    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        content
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
            .background(Color.white.opacity(hovering ? 0.03 : 0))
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
            .animation(.inertiaLiquid(speed: 1.5, reduceMotion: reduceMotion), value: hovering)
    }
}

// MARK: - Row labels (UI-7)

struct SettingsRowLabel: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 12.5))
                    .foregroundStyle(.white.opacity(0.50))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - SettingsToggleRow (UI-7)

struct SettingsToggleRow: View {
    let title: String
    var subtitle: String? = nil
    var accent: Color = .blue
    @Binding var isOn: Bool

    var body: some View {
        SettingsRow {
            HStack(spacing: 14) {
                SettingsRowLabel(title: title, subtitle: subtitle)
                Spacer(minLength: 12)
                Toggle("", isOn: $isOn)
                    .toggleStyle(InertiaToggleStyle(accent: accent))
                    .labelsHidden()
            }
        }
    }
}

// MARK: - SettingsSliderRow (UI-7)

struct SettingsSliderRow: View {
    var icon: String? = nil
    var iconColor: Color = .blue
    let title: String
    var subtitle: String? = nil
    @Binding var value: Double
    var range: ClosedRange<Double>
    var step: Double = 1
    var valueLabel: String
    var formatValue: ((Double) -> String)? = nil

    var body: some View {
        SettingsRow(minHeight: 72) {
            HStack(spacing: 14) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(iconColor)
                        .frame(width: 22)
                }
                SettingsRowLabel(title: title, subtitle: subtitle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                InertiaSlider(value: $value, range: range, step: step,
                              accent: iconColor, label: valueLabel,
                              formatValue: formatValue)
                    .frame(width: 212)
            }
            .padding(.vertical, 8)
        }
    }
}

// MARK: - InertiaSegmentedControl (UI-7)
/// Custom glass segmented control. Never falls back to a native macOS picker.

struct InertiaSegment<Value: Hashable>: Identifiable {
    let value: Value
    let title: String
    var id: Value { value }
}

struct InertiaSegmentedControl<Value: Hashable>: View {
    let options: [InertiaSegment<Value>]
    @Binding var selection: Value
    var accent: Color = .blue

    @Namespace private var namespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var liquid: Animation {
        .inertiaLiquid(speed: 1.2, reduceMotion: reduceMotion)
    }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(options) { option in
                Button {
                    withAnimation(liquid) { selection = option.value }
                } label: {
                    Text(option.title)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(selection == option.value ? .white : .white.opacity(0.48))
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                        .background {
                            if selection == option.value {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(LinearGradient(colors: [accent.opacity(0.38), accent.opacity(0.20)],
                                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .strokeBorder(accent.opacity(0.45), lineWidth: 0.7)
                                    )
                                    .matchedGeometryEffect(id: "segmentSelection", in: namespace)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.045))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(.white.opacity(0.07), lineWidth: 0.7)
                )
        )
        .animation(liquid, value: selection)
    }
}

// MARK: - SettingsChoiceRow (UI-7)

struct SettingsChoiceRow<Value: Hashable>: View {
    var icon: String? = nil
    var iconColor: Color = .blue
    let title: String
    var subtitle: String? = nil
    let options: [InertiaSegment<Value>]
    @Binding var selection: Value

    var body: some View {
        SettingsRow(minHeight: 64) {
            HStack(spacing: 12) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(iconColor)
                        .frame(width: 22)
                }
                SettingsRowLabel(title: title, subtitle: subtitle)
                Spacer(minLength: 18)
                InertiaSegmentedControl(options: options, selection: $selection, accent: iconColor)
                    .frame(width: 178)
            }
        }
    }
}

// MARK: - InertiaSelectTile (UI-7)
/// Large selectable glass tile used for Main display / Built-in display.
struct InertiaSelectTile: View {
    let title: String
    let subtitle: String
    let icon: String
    let isSelected: Bool
    let accent: Color
    let namespace: Namespace.ID
    let action: () -> Void

    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var liquid: Animation {
        .inertiaLiquid(speed: 1.1, reduceMotion: reduceMotion)
    }

    var body: some View {
        Button {
            withAnimation(liquid) { action() }
        } label: {
            HStack(spacing: 12) {
                SettingsIconTile(icon: icon,
                                 accent: isSelected ? accent : accent.opacity(0.55),
                                 size: 34, radius: 10)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(isSelected ? 1 : 0.66))
                    Text(subtitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.white.opacity(isSelected ? 0.52 : 0.36))
                        .lineLimit(2)
                }

                Spacer(minLength: 6)

                ZStack {
                    if isSelected {
                        Circle()
                            .fill(accent)
                            .frame(width: 21, height: 21)
                            .shadow(color: accent.opacity(0.65), radius: 7)
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                            )
                            .transition(.scale(scale: 0.55).combined(with: .opacity))
                    }
                }
                .frame(width: 21, height: 21)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(Color.white.opacity(isSelected ? 0.045 : 0.03))
                    if isSelected {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .fill(accent.opacity(0.13))
                            .overlay(
                                RoundedRectangle(cornerRadius: 15, style: .continuous)
                                    .strokeBorder(accent.opacity(0.60), lineWidth: 1)
                            )
                            .shadow(color: accent.opacity(0.28), radius: 12, y: 2)
                            .matchedGeometryEffect(id: "displayTargetTile", in: namespace)
                    }
                }
            }
            .opacity(isSelected ? 1 : 0.78)
            .scaleEffect(hovering && !isSelected && !reduceMotion ? 1.012 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        }
        .buttonStyle(InertiaPressStyle())
        .onHover { hovering = $0 }
        .animation(liquid, value: isSelected)
        .animation(liquid, value: hovering)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - DisplayTargetPicker (UI-7)

struct DisplayTargetPicker: View {
    @Binding var selection: DisplayTarget
    var accent: Color = SettingsPage.general.accent

    @Namespace private var namespace

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsRowLabel(title: "Show island on",
                             subtitle: "Choose which screen anchors the island.")
            HStack(spacing: 12) {
                ForEach(DisplayTarget.allCases, id: \.rawValue) { target in
                    InertiaSelectTile(
                        title: target.title,
                        subtitle: target.subtitle,
                        icon: target.symbolName,
                        isSelected: selection == target,
                        accent: accent,
                        namespace: namespace
                    ) {
                        selection = target
                    }
                }
            }
        }
        .padding(18)
    }
}

// MARK: - SettingsPlayButton (UI-7)
/// Round glass play button with a soft accent pulse while audio is playing.
struct SettingsPlayButton: View {
    var accent: Color = .blue
    let isPlaying: Bool
    var action: () -> Void

    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var liquid: Animation {
        .inertiaLiquid(speed: 1.4, reduceMotion: reduceMotion)
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.white.opacity(hovering ? 0.18 : 0.11),
                                                   .white.opacity(hovering ? 0.08 : 0.05)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(Circle().strokeBorder(.white.opacity(hovering ? 0.22 : 0.13), lineWidth: 0.7))

                if isPlaying && !reduceMotion {
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                        let time = context.date.timeIntervalSinceReferenceDate
                        let phase = (sin(time * 5.2) + 1) / 2
                        Circle()
                            .stroke(accent.opacity(0.55 * (1 - phase)), lineWidth: 1.4)
                            .scaleEffect(1 + 0.38 * phase)
                    }
                }

                Image(systemName: isPlaying ? "waveform" : "play.fill")
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(.white.opacity(0.86))
                    .offset(x: isPlaying ? 0 : 0.6)
            }
            .frame(width: 34, height: 34)
            .shadow(color: isPlaying ? accent.opacity(0.35) : .clear, radius: 8)
            .contentShape(Circle())
        }
        .buttonStyle(InertiaPressStyle())
        .onHover { hovering = $0 }
        .animation(liquid, value: hovering)
    }
}

// MARK: - SettingsDisclosureRow (UI-7)
/// A row with a pill play button instead of a bare disclosure chevron.
struct SettingsDisclosureRow: View {
    let title: String
    var subtitle: String? = nil
    var accent: Color = .blue
    var buttonTitle: String = "Preview"
    var action: () -> Void

    var body: some View {
        SettingsRow {
            HStack(spacing: 14) {
                SettingsRowLabel(title: title, subtitle: subtitle)
                Spacer(minLength: 12)
                Button(action: action) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10.5, weight: .bold))
                        Text(buttonTitle)
                            .font(.system(size: 12.5, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 32)
                    .background(
                        Capsule().fill(accent.opacity(0.20))
                    )
                    .overlay(Capsule().strokeBorder(accent.opacity(0.42), lineWidth: 0.8))
                    .contentShape(Capsule())
                }
                .buttonStyle(InertiaPressStyle())
            }
        }
    }
}

// MARK: - SectionLabel / PageHeader (UI-7)

struct SectionLabel: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(.white.opacity(0.40))
            .tracking(1.2)
            .padding(.leading, 4)
    }
}

struct PageHeader: View {
    let icon: String
    let title: String
    let description: String
    var accent: Color = .blue

    var body: some View {
        HStack(spacing: 16) {
            SettingsIconTile(icon: icon, accent: accent, size: 58, radius: 16)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                    .tracking(-0.3)
                Text(description)
                    .font(.system(size: 13.5))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(.bottom, 2)
    }
}

// MARK: - SidebarItem (UI-7)
/// Floating sidebar row. The selected glass capsule slides between rows with
/// matchedGeometryEffect under inertiaLiquid.
struct SidebarItem: View {
    let page: SettingsPage
    let isSelected: Bool
    let matchCount: Int
    let namespace: Namespace.ID
    let action: () -> Void

    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var liquid: Animation {
        .inertiaLiquid(speed: 1.15, reduceMotion: reduceMotion)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                SettingsIconTile(icon: page.sidebarIcon,
                                 accent: page.accent,
                                 size: 27, radius: 8)

                Text(page.title)
                    .font(.system(size: 13.5, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(.white.opacity(isSelected ? 1 : 0.72))

                Spacer(minLength: 4)

                if matchCount > 0 {
                    Text("\(matchCount)")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.72))
                        .padding(.horizontal, 6)
                        .frame(height: 18)
                        .background(Capsule().fill(.white.opacity(0.10)))
                }
            }
            .padding(.horizontal, 9)
            .frame(height: 40)
            .background {
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(LinearGradient(colors: [.white.opacity(0.15), page.accent.opacity(0.12)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(.white.opacity(0.12), lineWidth: 0.8)
                            )
                            .shadow(color: page.accent.opacity(0.16), radius: 8, y: 2)
                            .matchedGeometryEffect(id: "sidebarSelection", in: namespace)
                    } else if hovering {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.white.opacity(0.05))
                    }
                }
            }
            .scaleEffect(hovering && !isSelected && !reduceMotion ? 1.012 : 1)
            .offset(y: hovering && !isSelected && !reduceMotion ? -1 : 0)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(liquid, value: isSelected)
        .animation(liquid, value: hovering)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - IslandPreviewCard (UI-7)
/// Live, scaled preview of the island. Widths are passed in from FeatureSettings,
/// so there is no second source of truth for the slider values.
struct IslandPreviewCard: View {
    var islandWidth: Double
    var openPanelWidth: Double
    var accent: Color = .blue

    @State private var showOpen = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var liquid: Animation {
        .inertiaLiquid(speed: 1, reduceMotion: reduceMotion)
    }

    var body: some View {
        VStack(spacing: 0) {
            menuBar
            previewCanvas
            previewFooter
        }
    }

    private var menuBar: some View {
        HStack(spacing: 7) {
            Text("Inertia")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.42))
            Spacer()
            Image(systemName: "wifi")
            Image(systemName: "battery.75")
            Text("9:41")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
        }
        .font(.system(size: 9.5, weight: .medium))
        .foregroundStyle(.white.opacity(0.32))
        .padding(.horizontal, 14)
        .frame(height: 28)
        .background(Color.white.opacity(0.035))
        .overlay(alignment: .bottom) {
            Rectangle().fill(.white.opacity(0.06)).frame(height: 0.7)
        }
    }

    private var previewCanvas: some View {
        GeometryReader { geo in
            let available = max(geo.size.width - 48, 180)
            let scale = min(0.36, available / CGFloat(max(openPanelWidth, islandWidth, 1)))
            let width = CGFloat(showOpen ? openPanelWidth : islandWidth) * scale
            let height = showOpen
                ? IslandLayout.openPanelHeight * scale
                : max(16, 32 * scale)

            VStack(spacing: 9) {
                Spacer(minLength: 10)

                ZStack {
                    Ellipse()
                        .fill(RadialGradient(
                            colors: [accent.opacity(0.22), accent.opacity(0.05), .clear],
                            center: .center, startRadius: 0, endRadius: max(width * 0.55, 80)))
                        .frame(width: max(width * 1.7, 150), height: max(height * 2.1, 42))
                        .blur(radius: 14)

                    IslandShape(width: width, height: height, flare: 2)
                        .fill(LinearGradient(colors: [Color(white: 0.035), Color(white: 0.075)],
                                             startPoint: .top, endPoint: .bottom))
                    IslandShape(width: width, height: height, flare: 2)
                        .stroke(LinearGradient(colors: [.white.opacity(0.34), .white.opacity(0.08)],
                                                startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 0.9)
                    if showOpen {
                        VStack(spacing: 6) {
                            HStack(spacing: 4) {
                                Circle().fill(accent.opacity(0.85)).frame(width: 4, height: 4)
                                Circle().fill(.white.opacity(0.18)).frame(width: 4, height: 4)
                                Circle().fill(.white.opacity(0.18)).frame(width: 4, height: 4)
                            }
                            Capsule()
                                .fill(.white.opacity(0.16))
                                .frame(width: max(24, width * 0.42), height: 3)
                            Capsule()
                                .fill(.white.opacity(0.10))
                                .frame(width: max(18, width * 0.30), height: 3)
                        }
                        .offset(y: -height * 0.06)
                    }
                }
                .frame(width: width, height: height)
                .shadow(color: accent.opacity(0.38), radius: 14, y: 5)

                Text(showOpen
                     ? "Open panel · \(Int(openPanelWidth)) px"
                     : "Collapsed · \(Int(islandWidth)) px")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.38))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 158)
        .background(
            LinearGradient(colors: [accent.opacity(0.055), .clear],
                           startPoint: .top, endPoint: .bottom)
        )
        .animation(liquid, value: showOpen)
        .animation(liquid, value: islandWidth)
        .animation(liquid, value: openPanelWidth)
    }

    private var previewFooter: some View {
        HStack {
            Text("Live preview")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.32))
            Spacer()
            Button {
                withAnimation(liquid) { showOpen.toggle() }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: showOpen ? "rectangle.compress.vertical" : "rectangle.expand.vertical")
                        .font(.system(size: 10.5, weight: .semibold))
                    Text(showOpen ? "Collapsed" : "Open")
                        .font(.system(size: 11.5, weight: .semibold))
                }
                .foregroundStyle(.white.opacity(0.68))
                .padding(.horizontal, 12)
                .frame(height: 28)
                .background(Capsule().fill(.white.opacity(0.07)))
                .overlay(Capsule().strokeBorder(.white.opacity(0.10), lineWidth: 0.7))
                .contentShape(Capsule())
            }
            .buttonStyle(InertiaPressStyle())
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
    }
}

// MARK: - SettingsGlowBlobs (UI-7)
/// Three large, heavily blurred accent blobs that drift slowly behind the window.
struct SettingsGlowBlobs: View {
    var accent: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: reduceMotion)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                let drift1 = reduceMotion ? 0 : sin(t / 8.0) * 34
                let drift2 = reduceMotion ? 0 : cos(t / 10.0) * 42
                let drift3 = reduceMotion ? 0 : sin(t / 12.0 + 1.7) * 30

                ZStack {
                    Circle()
                        .fill(RadialGradient(
                            colors: [accent.opacity(0.16), accent.opacity(0.055), .clear],
                            center: .center, startRadius: 0, endRadius: 300))
                        .frame(width: 600, height: 600)
                        .blur(radius: 28)
                        .position(x: w * 0.16 + drift1, y: h * 0.10)
                    Circle()
                        .fill(RadialGradient(
                            colors: [accent.opacity(0.13), accent.opacity(0.04), .clear],
                            center: .center, startRadius: 0, endRadius: 340))
                        .frame(width: 680, height: 680)
                        .blur(radius: 32)
                        .position(x: w * 0.88 + drift2, y: h * 0.62)
                    Circle()
                        .fill(RadialGradient(
                            colors: [accent.opacity(0.10), accent.opacity(0.03), .clear],
                            center: .center, startRadius: 0, endRadius: 260))
                        .frame(width: 520, height: 520)
                        .blur(radius: 26)
                        .position(x: w * 0.52 + drift3, y: h * 1.02)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Staggered card entrance (UI-7)

private struct SettingsCardEntrance: ViewModifier {
    let index: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 10)
            .onAppear {
                guard !shown else { return }
                if reduceMotion {
                    shown = true
                } else {
                    withAnimation(.inertiaLiquid(speed: 1, reduceMotion: false)
                        .delay(Double(index) * 0.03)) {
                        shown = true
                    }
                }
            }
    }
}

extension View {
    /// Cards stagger in at 30ms intervals when a page first appears.
    func settingsCardEntrance(_ index: Int) -> some View {
        modifier(SettingsCardEntrance(index: index))
    }
}

// MARK: - SettingsPageSection (UI-7)
/// Section label plus glass card, with the card's staggered entrance baked in.
struct SettingsPageSection<Content: View>: View {
    let title: String
    let index: Int
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title: title)
            content.settingsCardEntrance(index)
        }
    }
}

// MARK: - SettingsPermissionRow (UI-7)

struct SettingsPermissionRow: View {
    var bundle: String? = nil
    var symbol: String = "lock.shield.fill"
    var symbolTint: Color = .blue
    let title: String
    let detail: String
    let state: PermState
    var action: (() -> Void)? = nil

    private var badge: (label: String, color: Color) {
        switch state {
        case .granted:       return ("Allowed", .green)
        case .denied:        return ("Denied", .red)
        case .notDetermined: return ("Not asked", .orange)
        case .notRunning:    return ("App closed", Color(white: 0.6))
        case .unknown:       return ("Unknown", Color(white: 0.6))
        }
    }

    private var buttonLabel: String? {
        switch state {
        case .granted:                 return nil
        case .denied:                  return "Open Settings"
        case .notRunning:              return "Open & Allow"
        case .notDetermined, .unknown: return "Allow"
        }
    }

    var body: some View {
        SettingsRow {
            HStack(spacing: 12) {
                Group {
                    if let bundle {
                        AppIconView(bundleID: bundle, size: 32)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    } else {
                        SettingsIconTile(icon: symbol, accent: symbolTint, size: 32, radius: 9)
                    }
                }
                .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        Text(title)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(badge.label)
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundStyle(badge.color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(badge.color.opacity(0.14)))
                    }
                    Text(detail)
                        .font(.system(size: 12.5))
                        .foregroundStyle(.white.opacity(0.50))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 10)

                if let buttonLabel, let action {
                    Button(buttonLabel, action: action)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .frame(height: 26)
                        .background(Capsule().fill(.white.opacity(0.13)))
                        .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 0.6))
                        .buttonStyle(InertiaPressStyle())
                        .fixedSize()
                }
            }
        }
    }
}
