import SwiftUI

// UI-7: Focus, Sound, Battery, Audio pages in the Inertia Glass language.

// MARK: - Focus Settings Page

struct FocusSettingsPage: View {
    @ObservedObject var feature = Store.shared.featureSettings
    private let accent = SettingsPage.focus.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(icon: "moon.fill",
                       title: "Focus",
                       description: "Island animation while Focus is active.",
                       accent: accent)

            SettingsPageSection(title: "Focus mode", index: 0) {
                SettingsCard(accent: accent) {
                    SettingsToggleRow(title: "Focus animation",
                                      subtitle: "Show a small island animation when Focus turns on or off.",
                                      accent: accent,
                                      isOn: $feature.showFocusAnimations)
                }
            }

            SettingsPageSection(title: "Animation", index: 1) {
                SettingsCard(accent: accent) {
                    VStack(spacing: 0) {
                        SettingsSliderRow(icon: "timer",
                                          iconColor: accent,
                                          title: "Animation duration",
                                          subtitle: "How long the Focus status stays visible.",
                                          value: $feature.focusAnimationDuration,
                                          range: 0.8...4, step: 0.2,
                                          valueLabel: String(format: "%.1fs", feature.focusAnimationDuration))
                            .disabled(!feature.showFocusAnimations)
                            .opacity(feature.showFocusAnimations ? 1 : 0.4)
                        SettingsDivider()
                        SettingsToggleRow(title: "Hide label",
                                          subtitle: "Hide the On/Off label on the right side of the island.",
                                          accent: accent,
                                          isOn: $feature.hideFocusLabel)
                            .disabled(!feature.showFocusAnimations)
                            .opacity(feature.showFocusAnimations ? 1 : 0.4)
                    }
                }
            }
        }
    }
}

// MARK: - Sound Settings Page

struct SoundSettingsPage: View {
    @ObservedObject var feature = Store.shared.featureSettings
    private let accent = SettingsPage.sound.accent

    private var displayOptions: [InertiaSegment<StatusDisplayStyle>] {
        StatusDisplayStyle.allCases.map { InertiaSegment(value: $0, title: $0.title) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(icon: "speaker.wave.2.fill",
                       title: "Sound",
                       description: "Volume change HUD in the island.",
                       accent: accent)

            SettingsPageSection(title: "Status", index: 0) {
                SettingsCard(accent: accent) {
                    SettingsToggleRow(title: "Sound status",
                                      subtitle: "Show a small island status when you change output volume manually.",
                                      accent: accent,
                                      isOn: $feature.showSoundStatus)
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
                                          selection: $feature.soundDisplayStyle)
                            .disabled(!feature.showSoundStatus)
                            .opacity(feature.showSoundStatus ? 1 : 0.4)
                        SettingsDivider()
                        SettingsSliderRow(icon: "slider.horizontal.3",
                                          iconColor: accent,
                                          title: "Line width",
                                          subtitle: "Adjust how much room the sound line uses.",
                                          value: $feature.soundLineWidth,
                                          range: 20...40, step: 2,
                                          valueLabel: "\(Int(feature.soundLineWidth))px")
                            .disabled(!feature.showSoundStatus || feature.soundDisplayStyle != .line)
                            .opacity(feature.showSoundStatus && feature.soundDisplayStyle == .line ? 1 : 0.4)
                    }
                }
            }
        }
    }
}

// MARK: - Battery Settings Page

struct BatterySettingsPage: View {
    @ObservedObject var feature = Store.shared.featureSettings
    @ObservedObject var store = Store.shared
    private let accent = SettingsPage.battery.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(icon: "battery.75",
                       title: "Battery",
                       description: "Low battery alerts and in-notch indicator.",
                       accent: accent)

            SettingsPageSection(title: "Behavior", index: 0) {
                SettingsCard(accent: accent) {
                    VStack(spacing: 0) {
                        SettingsToggleRow(title: "Battery alerts",
                                          subtitle: "Notify when power is connected, low, or full.",
                                          accent: accent,
                                          isOn: $store.batteryAlerts)
                        SettingsDivider()
                        SettingsToggleRow(title: "Battery in notch",
                                          subtitle: "Show battery percentage in the collapsed island.",
                                          accent: accent,
                                          isOn: $store.showBatteryInNotch)
                    }
                }
            }

            SettingsPageSection(title: "Low battery", index: 1) {
                SettingsCard(accent: accent) {
                    SettingsSliderRow(icon: "exclamationmark.triangle.fill",
                                      iconColor: accent,
                                      title: "Low battery threshold",
                                      subtitle: "Warn when the battery drops to this level.",
                                      value: Binding(
                                        get: { Double(feature.lowBatteryThreshold) },
                                        set: { feature.lowBatteryThreshold = Int($0) }
                                      ),
                                      range: 5...50, step: 5,
                                      valueLabel: "\(feature.lowBatteryThreshold)%")
                }
            }
        }
    }
}

// MARK: - Audio Settings Page

struct AudioSettingsPage: View {
    @ObservedObject var audio = AudioManager.shared
    @ObservedObject var bt = BluetoothManager.shared
    @ObservedObject var kb = KeyboardBrightnessManager.shared
    private let accent = SettingsPage.audio.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(icon: "headphones",
                       title: "Audio",
                       description: "Output device, keyboard brightness and Bluetooth.",
                       accent: accent)

            SettingsPageSection(title: "Output", index: 0) {
                SettingsCard(accent: accent) {
                    VStack(spacing: 0) {
                        SettingsRow {
                            HStack {
                                SettingsRowLabel(
                                    title: "Output Device",
                                    subtitle: audio.outputDeviceName.isEmpty ? "Default" : audio.outputDeviceName
                                )
                                Spacer()
                                Text(audio.isMuted ? "Muted" : "\(Int(audio.outputVolume * 100))%")
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.55))
                            }
                        }
                        SettingsDivider()
                        SettingsRow {
                            HStack {
                                SettingsRowLabel(
                                    title: "Keyboard Brightness",
                                    subtitle: "Adjust via hardware keys or system fallback."
                                )
                                Spacer()
                                Text("\(Int(kb.brightness * 100))%")
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.55))
                            }
                        }
                    }
                }
            }

            SettingsPageSection(title: "Bluetooth", index: 1) {
                SettingsCard(accent: accent) {
                    VStack(spacing: 0) {
                        SettingsRow {
                            HStack {
                                SettingsRowLabel(title: "Bluetooth Devices",
                                                 subtitle: "Connected devices and their battery level.")
                                Spacer()
                                Button("Refresh") { bt.refresh() }
                                    .font(.system(size: 12.5, weight: .semibold))
                                    .foregroundStyle(accent)
                                    .buttonStyle(InertiaPressStyle())
                            }
                        }
                        if !bt.connectedDevices.isEmpty {
                            ForEach(bt.connectedDevices.indices, id: \.self) { index in
                                SettingsDivider()
                                SettingsRow {
                                    HStack {
                                        AppIconView(bundleID: nil, size: 22, fallbackSystemName: "dot.radiowaves.left.and.right", fallbackColor: accent)
                                        Text(bt.connectedDevices[index].name)
                                            .font(.system(size: 13))
                                            .foregroundStyle(.white.opacity(0.80))
                                        Spacer()
                                        if let battery = bt.connectedDevices[index].battery {
                                            Text("\(battery)%")
                                                .font(.system(size: 12, design: .monospaced))
                                                .foregroundStyle(.white.opacity(0.48))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .onAppear { audio.update(); bt.refresh() }
    }
}
