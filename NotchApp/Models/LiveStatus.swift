import SwiftUI

enum LiveStatusKind: Equatable {
    case volume, focus, charging, network, brightness
}

enum LiveStatus: Equatable {
    case volume(Double, muted: Bool)
    case focus(Bool)
    case charging(Int)
    case network(String, Bool)
    case brightness(Double)

    var kind: LiveStatusKind {
        switch self {
        case .volume: return .volume
        case .focus: return .focus
        case .charging: return .charging
        case .network: return .network
        case .brightness: return .brightness
        }
    }

    var icon: String {
        switch self {
        case .volume(_, let muted): return muted ? "speaker.slash.fill" : "speaker.wave.2.fill"
        case .focus(let active): return active ? "moon.fill" : "moon"
        case .charging: return "bolt.fill"
        case .network(_, let connected): return connected ? "wifi" : "wifi.slash"
        case .brightness(let value): return value <= 0.33 ? "sun.min.fill" : value <= 0.66 ? "sun.max.fill" : "sun.max.fill"
        }
    }

    var tint: Color {
        switch self {
        case .volume: return Color(red: 0.52, green: 0.82, blue: 1.0)
        case .focus: return Color(red: 0.62, green: 0.76, blue: 1.0)
        case .charging: return .green
        case .network(_, let connected): return connected ? .green : .orange
        case .brightness: return Color(red: 1.0, green: 0.82, blue: 0.45)
        }
    }

    var title: String {
        switch self {
        case .volume(_, let muted): return muted ? "Muted" : "Volume"
        case .focus(let active): return active ? "Focus on" : "Focus off"
        case .charging: return "Charging"
        case .network(let label, _): return label
        case .brightness: return "Brightness"
        }
    }

    var fraction: Double? {
        switch self {
        case .volume(let value, let muted): return muted ? 0 : value
        case .charging(let percent): return Double(percent) / 100
        case .brightness(let value): return value
        default: return nil
        }
    }
}

struct LiveStatusBar: View {
    let status: LiveStatus
    let notch: NotchMetrics
    @ObservedObject var store = Store.shared
    @ObservedObject var feature = Store.shared.featureSettings

    var body: some View {
        let wing = max(store.wing, 110)
        let width = max(notch.width + wing, CGFloat(feature.islandWidth))
        let expansion = CGFloat(feature.hudExpansion) + 6

        VStack(spacing: 0) {
            // The notch area stays empty; nothing is drawn within the cutout.
            Color.clear.frame(height: notch.height)

            // HUD content lives below the notch, exactly like the hover music card.
            HStack(spacing: 10) {
                Image(systemName: status.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(status.tint)
                    .frame(width: 22)
                    .contentTransition(.symbolEffect(.replace))

                if showsTitle {
                    Text(status.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                        .transition(.opacity)
                }

                Spacer(minLength: 4)
                trailing
            }
            .padding(.horizontal, IslandLayout.contentInset)
            .frame(width: width, alignment: .leading)
        }
        .frame(width: width, height: notch.height + expansion, alignment: .top)
        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
    }

    private var showsTitle: Bool {
        switch status {
        case .focus:
            return !feature.hideFocusLabel
        case .volume:
            return feature.soundDisplayStyle == .line
        case .brightness:
            return feature.brightnessDisplayStyle == .line
        default:
            return true
        }
    }

    @ViewBuilder private var trailing: some View {
        switch status {
        case .volume(let value, let muted):
            if feature.soundDisplayStyle == .percent {
                percent(muted ? 0 : value)
            } else {
                line(muted ? 0 : value, width: feature.soundLineWidth)
            }
        case .brightness(let value):
            if feature.brightnessDisplayStyle == .percent {
                percent(value)
            } else {
                line(value, width: feature.brightnessLineWidth)
            }
        case .focus(let active):
            if !feature.hideFocusLabel {
                Text(active ? "On" : "Off")
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(status.tint)
            }
        case .charging(let value):
            Text("\(value)%")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
        case .network(_, let connected):
            Text(connected ? "Connected" : "Offline")
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(status.tint)
        }
    }

    private func percent(_ value: Double) -> some View {
        Text("\(Int((min(max(value, 0), 1) * 100).rounded()))%")
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(.white.opacity(0.9))
            .monospacedDigit()
    }

    private func line(_ value: Double, width: Double) -> some View {
        Capsule()
            .fill(.white.opacity(0.16))
            .frame(width: width, height: 4)
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(status.tint)
                    .frame(width: max(2, width * min(max(value, 0), 1)), height: 4)
            }
            .animation(.easeOut(duration: 0.12), value: value)
    }
}
