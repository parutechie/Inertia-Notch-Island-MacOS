import SwiftUI

// UI-7: Brightness page converted to the Inertia Glass layout.
struct BrightnessSettingsPage: View {
    @ObservedObject var feature = Store.shared.featureSettings
    @ObservedObject var store = Store.shared
    private let accent = SettingsPage.brightness.accent

    private var displayOptions: [InertiaSegment<StatusDisplayStyle>] {
        StatusDisplayStyle.allCases.map { InertiaSegment(value: $0, title: $0.title) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(icon: "sun.max.fill",
                       title: "Brightness",
                       description: "Display brightness HUD and in-notch battery status.",
                       accent: accent)

            SettingsPageSection(title: "Status", index: 0) {
                SettingsCard(accent: accent) {
                    VStack(spacing: 0) {
                        SettingsToggleRow(title: "Brightness",
                                          subtitle: "Show a small island status when you change display brightness manually.",
                                          accent: accent,
                                          isOn: $feature.showBrightnessStatus)
                        SettingsDivider()
                        SettingsToggleRow(title: "Show battery in notch",
                                          subtitle: "Display battery percentage beside the notch when idle.",
                                          accent: accent,
                                          isOn: $store.showBatteryInNotch)
                    }
                }
            }

            SettingsPageSection(title: "Appearance", index: 1) {
                SettingsCard(accent: accent) {
                    VStack(spacing: 0) {
                        SettingsChoiceRow(icon: "rectangle.split.3x1",
                                          iconColor: accent,
                                          title: "Display style",
                                          subtitle: "Choose a compact line or a numeric percentage.",
                                          options: displayOptions,
                                          selection: $feature.brightnessDisplayStyle)
                            .disabled(!feature.showBrightnessStatus)
                            .opacity(feature.showBrightnessStatus ? 1 : 0.4)
                        SettingsDivider()
                        SettingsSliderRow(icon: "slider.horizontal.3",
                                          iconColor: accent,
                                          title: "Line width",
                                          subtitle: "Adjust how much room the brightness line uses.",
                                          value: $feature.brightnessLineWidth,
                                          range: 20...40, step: 2,
                                          valueLabel: "\(Int(feature.brightnessLineWidth))px")
                            .disabled(!feature.showBrightnessStatus || feature.brightnessDisplayStyle != .line)
                            .opacity(feature.showBrightnessStatus && feature.brightnessDisplayStyle == .line ? 1 : 0.4)
                    }
                }
            }
        }
    }
}
