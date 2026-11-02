import SwiftUI
import AppKit

// UI-7: Inertia Glass Settings — window shell and pages.
// FeatureSettings / Store bindings, setting keys and reset/search logic are unchanged.
// Only layout and visuals differ from the previous implementation.

// MARK: - Root view

struct SettingsRootView: View {
    @ObservedObject var store = Store.shared
    @State private var searchText: String
    @Namespace private var sidebarNS
    @FocusState private var searchFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(initialSearch: String = "") {
        _searchText = State(initialValue: initialSearch)
    }

    private var groups: [(title: String?, pages: [SettingsPage])] { SettingsCatalog.groups }
    private var searchResults: [SettingsSearchItem] { SettingsCatalog.search(searchText) }
    private var isSearching: Bool { !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var liquid: Animation { .inertiaLiquid(speed: 1, reduceMotion: reduceMotion) }
    private var pageTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(
                insertion: .opacity.combined(with: .offset(y: 12)),
                removal: .opacity.combined(with: .offset(y: -8))
            )
    }

    var body: some View {
        ZStack {
            // UI-7: deep near-black base.
            Color(white: 0.04).ignoresSafeArea()

            // UI-7: drifting accent glow, tinted by the selected page.
            SettingsGlowBlobs(accent: store.settingsPage.accent)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.easeInOut(duration: 0.6), value: store.settingsPage)

            // UI-7: shared noise grain from the island design kit.
            Image(nsImage: InertiaNoiseTexture.image)
                .resizable(resizingMode: .tile)
                .opacity(0.028)
                .blendMode(.plusLighter)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            // UI-7: faint top sheen.
            LinearGradient(
                stops: [
                    .init(color: .white.opacity(0.055), location: 0),
                    .init(color: .white.opacity(0.012), location: 0.16),
                    .init(color: .clear, location: 0.42)
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            HStack(spacing: 0) {
                sidebar
                    .frame(width: 232)
                    .padding(.leading, 12)
                    .padding(.vertical, 12)

                detail
                    .padding(.trailing, 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
        .ignoresSafeArea(.container, edges: .top)
        .onAppear { store.refreshPermissions() }
    }

    // MARK: Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(.white.opacity(0.14), lineWidth: 0.7)
                    )
                VStack(alignment: .leading, spacing: 0) {
                    Text("Inertia")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Settings")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.38))
                }
                Spacer()
            }
            .padding(.top, 28)
            .padding(.horizontal, 16)

            searchField
                .padding(.horizontal, 12)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(filteredGroups.enumerated()), id: \.offset) { _, group in
                        if let title = group.title {
                            sidebarGroup(title: title, pages: group.pages)
                        } else {
                            VStack(spacing: 2) {
                                ForEach(group.pages) { sidebarRow($0) }
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 16)
            }
        }
        .background {
            InertiaGlassLayer(
                tint: store.settingsPage.accent,
                tintOpacity: 0.065,
                materialOpacity: 0.34,
                noiseOpacity: 0.04,
                highlightOpacity: 0.14
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(
                    LinearGradient(colors: [.white.opacity(0.14), .white.opacity(0.04)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.8
                )
        )
        .shadow(color: .black.opacity(0.28), radius: 20, y: 10)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(.white.opacity(searchFocused ? 0.70 : 0.40))

            TextField("Search settings…", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(.white)
                .focused($searchFocused)
                .onSubmit {
                    if let first = searchResults.first { open(first) }
                }

            if isSearching {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.35))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .inertiaGlassBackground(
            cornerRadius: 18,
            showsStroke: false,
            tint: store.settingsPage.accent,
            gloss: searchFocused ? 0.8 : 0.5,
            materialOpacity: 0.24,
            noiseOpacity: 0.035,
            highlightOpacity: 0.14
        )
        .overlay(
            Capsule().strokeBorder(
                searchFocused ? store.settingsPage.accent.opacity(0.70) : .white.opacity(0.09),
                lineWidth: searchFocused ? 1.1 : 0.7
            )
        )
        .background(
            Capsule()
                .stroke(store.settingsPage.accent.opacity(searchFocused ? 0.28 : 0), lineWidth: 4)
                .blur(radius: 5)
        )
        .animation(liquid, value: searchFocused)
        .animation(.easeInOut(duration: 0.25), value: store.settingsPage)
    }

    private var filteredGroups: [(title: String?, pages: [SettingsPage])] {
        guard isSearching else { return groups }
        return groups.compactMap { group in
            let pages = group.pages.filter {
                SettingsCatalog.matchCount(for: $0, in: searchResults) > 0
            }
            return pages.isEmpty ? nil : (group.title, pages)
        }
    }

    private func sidebarGroup(title: String, pages: [SettingsPage]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.40))
                .tracking(1.2)
                .padding(.leading, 10)
                .padding(.bottom, 3)
            ForEach(pages) { sidebarRow($0) }
        }
    }

    private func sidebarRow(_ page: SettingsPage) -> some View {
        SidebarItem(
            page: page,
            isSelected: store.settingsPage == page,
            matchCount: isSearching ? SettingsCatalog.matchCount(for: page, in: searchResults) : 0,
            namespace: sidebarNS
        ) {
            activate(page)
        }
    }

    // MARK: Detail

    private var detail: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    pageContent
                }
                .frame(maxWidth: 840, alignment: .topLeading)
                .frame(maxWidth: .infinity, alignment: .top)
                .padding(.horizontal, 24)
                .padding(.top, 10)
                .padding(.bottom, 40)
            }
            .id(store.settingsPage) // reset scroll on page change
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 0) {
                Button { select(offset: -1) } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 34, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(InertiaPressStyle())

                Rectangle()
                    .fill(.white.opacity(0.10))
                    .frame(width: 0.7, height: 16)

                Button { select(offset: 1) } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 34, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(InertiaPressStyle())
            }
            .foregroundStyle(.white.opacity(0.60))
            .disabled(isSearching)
            .opacity(isSearching ? 0.30 : 1)
            .background(Capsule().fill(.white.opacity(0.065)))
            .overlay(Capsule().strokeBorder(.white.opacity(0.08), lineWidth: 0.7))
            .clipShape(Capsule())

            VStack(alignment: .leading, spacing: 1) {
                Text(isSearching ? "Search Results" : store.settingsPage.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                if isSearching {
                    Text("\(searchResults.count) setting\(searchResults.count == 1 ? "" : "s") found")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.42))
                }
            }

            Spacer()

            if !isSearching, supportsReset(store.settingsPage) {
                Button { resetSelectedPage() } label: {
                    Text("Reset")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.60))
                        .padding(.horizontal, 14)
                        .frame(height: 29)
                        .background(Capsule().strokeBorder(.white.opacity(0.14), lineWidth: 0.8))
                        .contentShape(Capsule())
                }
                .buttonStyle(InertiaPressStyle())
            }
        }
        .padding(.horizontal, 24)
        .frame(height: 60)
        .background {
            ZStack {
                WindowDragHandle()
                Color.white.opacity(0.018)
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(.white.opacity(0.06)).frame(height: 0.7)
        }
    }

    @ViewBuilder
    private var pageContent: some View {
        if isSearching {
            SettingsSearchResultsPage(results: searchResults, open: open)
                .transition(pageTransition)
        } else {
            Group {
                switch store.settingsPage {
                case .general:     GeneralSettingsPage()
                case .focus:       FocusSettingsPage()
                case .sound:       SoundSettingsPage()
                case .brightness:  BrightnessSettingsPage()
                case .battery:     BatterySettingsPage()
                case .audio:       AudioSettingsPage()
                case .music:       MusicSettingsPage()
                case .calendar:    CalendarSettingsPage()
                case .permissions: PermissionsSettingsPage()
                case .about:       AboutSettingsPage()
                }
            }
            .transition(pageTransition)
            .id(store.settingsPage)
        }
    }

    // MARK: Helpers (logic unchanged)

    private func activate(_ page: SettingsPage) {
        withAnimation(liquid) {
            if isSearching { searchText = "" }
            store.settingsPage = page
        }
    }

    private func open(_ result: SettingsSearchItem) {
        searchFocused = false
        withAnimation(liquid) {
            searchText = ""
            store.settingsPage = result.page
        }
    }

    private func select(offset: Int) {
        let pages = SettingsPage.allCases
        guard let index = pages.firstIndex(of: store.settingsPage) else { return }
        let next = (index + offset + pages.count) % pages.count
        withAnimation(liquid) {
            store.settingsPage = pages[next]
        }
    }

    private func supportsReset(_ page: SettingsPage) -> Bool {
        switch page {
        case .general, .focus, .sound, .brightness, .battery, .audio, .music: return true
        case .calendar, .permissions, .about: return false
        }
    }

    private func resetSelectedPage() {
        withAnimation(liquid) {
            switch store.settingsPage {
            case .general:    store.featureSettings.resetGeneral(); store.featureSettings.resetIntro()
            case .focus:      store.featureSettings.resetFocus()
            case .sound:      store.featureSettings.resetSound()
            case .brightness: store.featureSettings.resetBrightness()
            case .battery:    store.featureSettings.resetBattery()
            case .audio:      break
            case .music:      store.featureSettings.resetMusic()
            case .calendar, .permissions, .about: break
            }
        }
    }
}

// MARK: - Search results page (UI-7)

private struct SettingsSearchResultsPage: View {
    let results: [SettingsSearchItem]
    let open: (SettingsSearchItem) -> Void

    private var grouped: [(page: SettingsPage, items: [SettingsSearchItem])] {
        SettingsPage.allCases.compactMap { page in
            let items = results.filter { $0.page == page }
            return items.isEmpty ? nil : (page, items)
        }
    }

    var body: some View {
        if results.isEmpty {
            VStack(spacing: 12) {
                SettingsIconTile(icon: "magnifyingglass", accent: .gray, size: 48, radius: 15)
                Text("No settings found")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.65))
                Text("Try a different word, such as volume, emoji, or permissions.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.white.opacity(0.38))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 70)
        } else {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(grouped.enumerated()), id: \.element.page) { index, group in
                    SettingsPageSection(title: group.page.title, index: index) {
                        SettingsCard(accent: group.page.accent) {
                            VStack(spacing: 0) {
                                ForEach(Array(group.items.enumerated()), id: \.element.id) { i, item in
                                    if i > 0 { SettingsDivider() }
                                    resultRow(item, accent: group.page.accent)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func resultRow(_ item: SettingsSearchItem, accent: Color) -> some View {
        Button { open(item) } label: {
            SettingsRow {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.title)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white)
                        if let subtitle = item.subtitle {
                            Text(subtitle)
                                .font(.system(size: 12.5))
                                .foregroundStyle(.white.opacity(0.48))
                                .lineLimit(2)
                        }
                    }
                    Spacer(minLength: 16)
                    Text(item.page.title)
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(accent.opacity(0.85))
                        .padding(.horizontal, 7)
                        .frame(height: 18)
                        .background(Capsule().fill(accent.opacity(0.14)))
                    Image(systemName: "arrow.up.forward")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.25))
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Window drag (unchanged)

struct WindowDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> WindowDragHandleNSView { WindowDragHandleNSView() }
    func updateNSView(_ nsView: WindowDragHandleNSView, context: Context) {}
}

final class WindowDragHandleNSView: NSView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { bounds.contains(point) ? self : nil }
    override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
}

// MARK: - SettingsPage icons

extension SettingsPage {
    var sidebarIcon: String {
        switch self {
        case .general:     return "gearshape"
        case .focus:       return "moon.fill"
        case .sound:       return "speaker.wave.2.fill"
        case .brightness:  return "sun.max.fill"
        case .battery:     return "battery.75"
        case .audio:       return "headphones"
        case .music:       return "music.note"
        case .calendar:    return "calendar"
        case .permissions: return "lock.shield"
        case .about:       return "info.circle"
        }
    }
}

// MARK: - General Settings Page (UI-7)

struct GeneralSettingsPage: View {
    @ObservedObject var store = Store.shared
    @ObservedObject var feature = Store.shared.featureSettings
    private let accent = SettingsPage.general.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(icon: "gearshape",
                       title: "General",
                       description: "Display, island layout, emoji, sound, and startup behavior.",
                       accent: accent)

            // Unique touch: live island preview.
            SettingsPageSection(title: "Live preview", index: 0) {
                SettingsCard(accent: accent) {
                    IslandPreviewCard(islandWidth: feature.islandWidth,
                                      openPanelWidth: feature.openPanelWidth,
                                      accent: accent)
                }
            }

            SettingsPageSection(title: "Display", index: 1) {
                SettingsCard(accent: accent) {
                    DisplayTargetPicker(selection: $feature.displayTarget, accent: accent)
                }
            }

            // Both width sliders are peers: same weight, no nesting or indent.
            SettingsPageSection(title: "Island size", index: 2) {
                SettingsCard(accent: accent) {
                    VStack(spacing: 0) {
                        SettingsSliderRow(icon: "rectangle.portrait",
                                          iconColor: accent,
                                          title: "Island Width",
                                          subtitle: "Set the base width used by the dynamic island.",
                                          value: $feature.islandWidth,
                                          range: 280...360, step: 2,
                                          valueLabel: "\(Int(feature.islandWidth))px")
                        SettingsDivider()
                        SettingsSliderRow(icon: "rectangle.expand.vertical",
                                          iconColor: accent,
                                          title: "Open Panel Width",
                                          subtitle: "Set the width of the expanded island.",
                                          value: $feature.openPanelWidth,
                                          range: IslandLayout.openPanelMinWidth...IslandLayout.openPanelMaxWidth,
                                          step: 4,
                                          valueLabel: "\(Int(feature.openPanelWidth))px")
                    }
                }
            }

            SettingsPageSection(title: "Behavior", index: 3) {
                SettingsCard(accent: accent) {
                    VStack(spacing: 0) {
                        SettingsToggleRow(title: "Hide in Fullscreen",
                                          subtitle: "Hide the island while the active app is fullscreen.",
                                          accent: accent,
                                          isOn: $feature.hideNotchWhenFullscreen)
                        SettingsDivider()
                        SettingsToggleRow(title: "Network Status",
                                          subtitle: "Show Wi-Fi, Personal Hotspot, and internet availability changes.",
                                          accent: accent,
                                          isOn: $store.showNetworkInNotch)
                        SettingsDivider()
                        SettingsSliderRow(icon: "speedometer",
                                          iconColor: accent,
                                          title: "Animation Speed",
                                          subtitle: "Multiplier for every island animation.",
                                          value: $store.animSpeed,
                                          range: 0.5...2, step: 0.1,
                                          valueLabel: String(format: "%.1f×", store.animSpeed))
                    }
                }
            }

            SettingsPageSection(title: "Startup & intro", index: 4) {
                SettingsCard(accent: accent) {
                    VStack(spacing: 0) {
                        SettingsToggleRow(title: "Launch at Login",
                                          subtitle: "Open Inertia automatically when you sign in.",
                                          accent: accent,
                                          isOn: $store.launchAtLogin)
                        SettingsDivider()
                        SettingsToggleRow(title: "Play intro on launch",
                                          subtitle: "Show the handwritten hello when Inertia starts.",
                                          accent: accent,
                                          isOn: $feature.introEnabled)
                        SettingsDivider()
                        SettingsDisclosureRow(title: "Preview intro",
                                              subtitle: "Play the intro animation right now.",
                                              accent: accent,
                                              buttonTitle: "Preview") {
                            Store.shared.startIntro(force: true)
                        }
                    }
                }
            }

            SettingsPageSection(title: "Sound", index: 5) {
                SettingsCard(accent: accent) {
                    VStack(spacing: 0) {
                        UnlockSoundSettingsRow(isEnabled: $feature.enableLockSound)
                        SettingsDivider()
                        SettingsToggleRow(title: "Alert Sounds",
                                          subtitle: "Play a chime when a reminder or focus timer fires.",
                                          accent: accent,
                                          isOn: $store.alertSounds)
                        SettingsDivider()
                        SettingsToggleRow(title: "Speak Reminders",
                                          subtitle: "Read reminder titles aloud using your system voice.",
                                          accent: accent,
                                          isOn: $store.speakReminders)
                    }
                }
            }

            SettingsPageSection(title: "Live activities", index: 6) {
                SettingsCard(accent: accent) {
                    VStack(spacing: 0) {
                        SettingsSliderRow(icon: "timer",
                                          iconColor: accent,
                                          title: "HUD duration",
                                          subtitle: "How long live status updates stay visible.",
                                          value: $feature.hudDuration,
                                          range: 0.8...6, step: 0.2,
                                          valueLabel: String(format: "%.1fs", feature.hudDuration))
                        SettingsDivider()
                        SettingsSliderRow(icon: "rectangle.topthird.inset.filled",
                                          iconColor: accent,
                                          title: "Expansion below notch",
                                          subtitle: "Give HUDs extra height beneath the physical notch.",
                                          value: $feature.hudExpansion,
                                          range: 0...18, step: 2,
                                          valueLabel: "\(Int(feature.hudExpansion))px")
                        SettingsDivider()
                        SettingsToggleRow(title: "Queue status updates",
                                          subtitle: "Show changes one after another instead of replacing each other.",
                                          accent: accent,
                                          isOn: $feature.hudQueueEnabled)
                    }
                }
            }

            SettingsPageSection(title: "Emoji", index: 7) {
                SettingsCard(accent: accent) {
                    VStack(spacing: 0) {
                        SettingsToggleRow(title: "Left emoji",
                                          subtitle: "Show a customizable character or animation on the left side of the island.",
                                          accent: accent,
                                          isOn: $feature.showNotchEmoji)
                        SettingsDivider()
                        SettingsToggleRow(title: "Use Lottie animation",
                                          subtitle: "Show an animated Lottie loader instead of a text character.",
                                          accent: accent,
                                          isOn: $feature.leftEmojiUseLottie)
                            .disabled(!feature.showNotchEmoji)
                            .opacity(feature.showNotchEmoji ? 1 : 0.4)
                        SettingsDivider()
                        emojiCharacterRow(title: "Left character", placeholder: "🤍", text: $feature.notchEmoji)
                            .disabled(!feature.showNotchEmoji || feature.leftEmojiUseLottie)
                            .opacity(feature.showNotchEmoji && !feature.leftEmojiUseLottie ? 1 : 0.4)
                        SettingsDivider()
                        SettingsToggleRow(title: "Right emoji",
                                          subtitle: "Show a second character on the right side of the island.",
                                          accent: accent,
                                          isOn: $feature.showRightNotchEmoji)
                        SettingsDivider()
                        emojiCharacterRow(title: "Right character", placeholder: "✨", text: $feature.rightNotchEmoji)
                            .disabled(!feature.showRightNotchEmoji)
                            .opacity(feature.showRightNotchEmoji ? 1 : 0.4)
                        SettingsDivider()
                        SettingsToggleRow(title: "Only when idle",
                                          subtitle: "Hide emoji while music, meetings, Focus, privacy, or live statuses are active.",
                                          accent: accent,
                                          isOn: $feature.emojiOnlyWhenIdle)
                        SettingsDivider()
                        SettingsSliderRow(icon: "textformat.size",
                                          iconColor: accent,
                                          title: "Size",
                                          subtitle: "Adjust how large the emoji appears.",
                                          value: $feature.notchEmojiSize,
                                          range: 12...22, step: 1,
                                          valueLabel: "\(Int(feature.notchEmojiSize))px")
                            .disabled(!feature.showNotchEmoji && !feature.showRightNotchEmoji)
                            .opacity(feature.showNotchEmoji || feature.showRightNotchEmoji ? 1 : 0.4)
                    }
                }
            }

            SettingsPageSection(title: "Notifications", index: 8) {
                SettingsCard(accent: accent) {
                    SettingsToggleRow(title: "System Notification Banners",
                                      subtitle: "Also send a standard macOS banner when a reminder fires.",
                                      accent: accent,
                                      isOn: $store.systemNotifications)
                }
            }

            SettingsPageSection(title: "Privacy & shelf", index: 9) {
                SettingsCard(accent: accent) {
                    VStack(spacing: 0) {
                        SettingsToggleRow(title: "Privacy Indicators",
                                          subtitle: "Show microphone, camera and screen-share status beside the notch.",
                                          accent: accent,
                                          isOn: $store.showPrivacyIndicators)
                        SettingsDivider()
                        SettingsToggleRow(title: "Clipboard History",
                                          subtitle: "Keep text, links, images and files you copy on the Shelf.",
                                          accent: accent,
                                          isOn: $store.clipboardEnabled)
                    }
                }
            }

            SettingsPageSection(title: "Alerts", index: 10) {
                SettingsCard(accent: accent) {
                    VStack(spacing: 0) {
                        SettingsToggleRow(title: "Charging & Battery Alerts",
                                          subtitle: "Notify when power is connected, low, or full.",
                                          accent: accent,
                                          isOn: $store.batteryAlerts)
                        SettingsDivider()
                        SettingsToggleRow(title: "Network Alerts",
                                          subtitle: "Notify when you go offline or come back online.",
                                          accent: accent,
                                          isOn: $store.networkAlerts)
                    }
                }
            }
        }
    }

    private func emojiCharacterRow(title: String, placeholder: String,
                                   text: Binding<String>) -> some View {
        SettingsRow {
            HStack(spacing: 12) {
                SettingsRowLabel(title: title,
                                 subtitle: "Use an emoji or a short symbol.")
                Spacer()
                TextField(placeholder, text: text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 20))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color.white.opacity(0.07))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(.white.opacity(0.10), lineWidth: 0.7)
                    )
                    .onChange(of: text.wrappedValue) { _, value in
                        if value.count > 8 { text.wrappedValue = String(value.prefix(8)) }
                    }
            }
        }
    }
}

// MARK: - UnlockSoundSettingsRow (UI-7)

private struct UnlockSoundSettingsRow: View {
    @Binding var isEnabled: Bool
    @State private var playing = false
    private let accent = SettingsPage.general.accent

    var body: some View {
        SettingsRow {
            HStack(spacing: 12) {
                SettingsRowLabel(title: "Unlock Sound",
                                 subtitle: "Play a subtle sound when your Mac unlocks.")
                Spacer(minLength: 12)
                SettingsPlayButton(accent: accent, isPlaying: playing) {
                    playing = true
                    UnlockSoundPlayer.shared.play(bypassThrottle: true)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        playing = false
                    }
                }
                Toggle("", isOn: $isEnabled)
                    .toggleStyle(InertiaToggleStyle(accent: accent))
                    .labelsHidden()
            }
        }
    }
}

// MARK: - Music Settings Page (UI-7)

struct MusicSettingsPage: View {
    @ObservedObject var store = Store.shared
    @ObservedObject var feature = Store.shared.featureSettings
    private let accent = SettingsPage.music.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(icon: "music.note",
                       title: "Music",
                       description: "Now playing, lyrics, and player integrations.",
                       accent: accent)

            SettingsPageSection(title: "Playback", index: 0) {
                SettingsCard(accent: accent) {
                    VStack(spacing: 0) {
                        SettingsToggleRow(title: "Show music in the notch",
                                          subtitle: "Show the app icon and live equalizer while something plays.",
                                          accent: accent,
                                          isOn: $store.showMusicInNotch)
                        SettingsDivider()
                        SettingsToggleRow(title: "Peek when track changes",
                                          subtitle: "Briefly widen the notch to show the new song title.",
                                          accent: accent,
                                          isOn: $store.trackPeek)
                        SettingsDivider()
                        SettingsToggleRow(title: "Synced lyrics",
                                          subtitle: "Fetch time-synced lyrics from LRCLIB and follow the current line.",
                                          accent: accent,
                                          isOn: $store.showLyrics)
                    }
                }
            }

            SettingsPageSection(title: "Preview", index: 1) {
                SettingsCard(accent: accent) {
                    SettingsSliderRow(icon: "timer",
                                      iconColor: accent,
                                      title: "Preview duration",
                                      subtitle: "How long the track title stays visible when the song changes.",
                                      value: $feature.musicPreviewDuration,
                                      range: 0.5...6, step: 0.5,
                                      valueLabel: String(format: "%.1fs", feature.musicPreviewDuration))
                }
            }

            preciseModeSection
        }
    }

    @ViewBuilder
    private var preciseModeSection: some View {
        let anyReady = store.jsReady.values.contains(true)
        SettingsPageSection(title: "Precise Browser Mode", index: 2) {
            SettingsCard(accent: accent) {
                VStack(spacing: 0) {
                    if anyReady {
                        SettingsRow {
                            HStack(spacing: 10) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("Precise mode is active for at least one browser.")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.white.opacity(0.70))
                            }
                        }
                    } else {
                        SettingsRow(minHeight: 52) {
                            Text("Install the browser extension to read real play state, artist and artwork.")
                                .font(.system(size: 12.5))
                                .foregroundStyle(.white.opacity(0.50))
                                .lineLimit(3)
                        }
                    }

                    ForEach(Array(store.jsReady.keys).sorted(), id: \.self) { bundle in
                        SettingsDivider()
                        browserInstructionRow(bundle: bundle)
                    }
                }
            }
        }
    }

    private func browserInstructionRow(bundle: String) -> some View {
        SettingsRow {
            HStack(spacing: 10) {
                AppIconView(bundleID: bundle, size: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                SettingsRowLabel(
                    title: bundle,
                    subtitle: store.jsReady[bundle] == true ? "Connected" : "Not connected"
                )
                Spacer()
                Button("Open") { store.launch(bundle) }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(accent)
                    .buttonStyle(InertiaPressStyle())
            }
        }
    }
}

// MARK: - Calendar Settings Page (UI-7)

struct CalendarSettingsPage: View {
    @ObservedObject private var engine = CalendarEngine.shared
    @ObservedObject var store = Store.shared
    private let accent = SettingsPage.calendar.accent

    private var status: (title: String, detail: String, color: Color) {
        switch engine.access {
        case .granted:
            return ("Connected", "Inertia can read your Apple Calendar and add events to it.", .green)
        case .denied, .restricted:
            return ("Access denied", "Enable access in System Settings. New events stay inside Inertia.", .red)
        case .notDetermined:
            return ("Not connected", "Connect Apple Calendar to see your schedule in the notch.", .orange)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(icon: "calendar",
                       title: "Calendar",
                       description: "Upcoming events and meeting alerts.",
                       accent: accent)

            SettingsPageSection(title: "Access", index: 0) {
                SettingsCard(accent: accent) {
                    SettingsRow(minHeight: 64) {
                        HStack(spacing: 12) {
                            SettingsIconTile(icon: "calendar", accent: accent, size: 32, radius: 9)
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 7) {
                                    Text("Calendar access")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(.white)
                                    Text(status.title)
                                        .font(.system(size: 9.5, weight: .bold))
                                        .foregroundStyle(status.color)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(status.color.opacity(0.14)))
                                }
                                Text(status.detail)
                                    .font(.system(size: 12.5))
                                    .foregroundStyle(.white.opacity(0.50))
                                    .lineLimit(2)
                            }
                            Spacer(minLength: 10)
                            if engine.access == .granted {
                                Button("Refresh") { engine.reload() }
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(accent)
                                    .buttonStyle(InertiaPressStyle())
                            } else if engine.access == .notDetermined {
                                Button("Connect") { engine.requestAccess() }
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(accent)
                                    .buttonStyle(InertiaPressStyle())
                            } else {
                                Button("Open Settings") { store.openPrivacy("Privacy_Calendars") }
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(accent)
                                    .buttonStyle(InertiaPressStyle())
                            }
                        }
                    }
                }
            }

            SettingsPageSection(title: "Notch alerts", index: 1) {
                SettingsCard(accent: accent) {
                    SettingsToggleRow(title: "Upcoming event alerts",
                                      subtitle: "Show a notch alert five minutes before an event starts.",
                                      accent: accent,
                                      isOn: $store.calendarAlerts)
                }
            }

            if !engine.localEvents.isEmpty {
                SettingsPageSection(title: "Local events", index: 2) {
                    SettingsCard(accent: accent) {
                        SettingsRow {
                            HStack(spacing: 12) {
                                SettingsIconTile(icon: "internaldrive", accent: .gray, size: 32, radius: 9)
                                SettingsRowLabel(
                                    title: "\(engine.localEvents.count) local event\(engine.localEvents.count == 1 ? "" : "s")",
                                    subtitle: "Created while Calendar access was unavailable. Stored only on this Mac."
                                )
                                Spacer()
                                Button("Erase") { engine.eraseLocalEvents() }
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.red.opacity(0.85))
                                    .buttonStyle(InertiaPressStyle())
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Permissions Settings Page (UI-7)

struct PermissionsSettingsPage: View {
    @ObservedObject var store = Store.shared
    @ObservedObject var calendar = CalendarEngine.shared
    private let accent = SettingsPage.permissions.accent

    private var calendarState: PermState {
        switch calendar.access {
        case .granted: return .granted
        case .denied, .restricted: return .denied
        case .notDetermined: return .notDetermined
        }
    }

    private var installedApps: [MediaApp] {
        Store.mediaApps.filter { $0.installed }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(icon: "lock.shield",
                       title: "Permissions",
                       description: "Allow Inertia to control apps and read system state. Nothing leaves your Mac.",
                       accent: accent)

            if !installedApps.isEmpty {
                SettingsPageSection(title: "Automation", index: 0) {
                    SettingsCard(accent: accent) {
                        VStack(spacing: 0) {
                            ForEach(Array(installedApps.enumerated()), id: \.element.id) { index, app in
                                if index > 0 { SettingsDivider() }
                                SettingsPermissionRow(
                                    bundle: app.bundle,
                                    title: app.name,
                                    detail: app.kind == .player
                                        ? "Read current track, send play / pause / skip."
                                        : "See which tab is playing and control it.",
                                    state: store.perms[app.bundle] ?? .unknown
                                ) {
                                    let state = store.perms[app.bundle] ?? .unknown
                                    if state == .denied {
                                        store.openPrivacy("Privacy_Automation")
                                    } else {
                                        store.requestAutomation(app.bundle)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            SettingsPageSection(title: "System", index: 1) {
                SettingsCard(accent: accent) {
                    VStack(spacing: 0) {
                        SettingsPermissionRow(
                            symbol: "hand.tap",
                            symbolTint: Color(red: 0.40, green: 0.75, blue: 1.00),
                            title: "Accessibility",
                            detail: "Send media key events when a player can't be scripted directly.",
                            state: store.axTrusted ? .granted : .notDetermined
                        ) {
                            store.requestAccessibility()
                            store.openPrivacy("Privacy_Accessibility")
                        }
                        SettingsDivider()
                        SettingsPermissionRow(
                            symbol: "bell.badge",
                            symbolTint: Color(red: 1.00, green: 0.42, blue: 0.62),
                            title: "Notifications",
                            detail: "Show standard macOS banners for reminders.",
                            state: store.notifAuthorized ? .granted : .notDetermined
                        ) {
                            store.requestNotifications()
                            store.openNotificationSettings()
                        }
                        SettingsDivider()
                        SettingsPermissionRow(
                            symbol: "calendar",
                            symbolTint: accent,
                            title: "Calendar",
                            detail: "Read your schedule and add events. Optional — without it events stay local.",
                            state: calendarState
                        ) {
                            if calendar.access == .notDetermined {
                                calendar.requestAccess()
                            } else {
                                store.openPrivacy("Privacy_Calendars")
                            }
                        }
                    }
                }
            }

            SettingsPageSection(title: "Maintenance", index: 2) {
                SettingsCard(accent: accent) {
                    SettingsRow {
                        HStack {
                            SettingsRowLabel(
                                title: "Re-check all permissions",
                                subtitle: "Refresh the status of every app and system permission."
                            )
                            Spacer()
                            Button("Re-check") { store.refreshPermissions() }
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundStyle(accent)
                                .buttonStyle(InertiaPressStyle())
                        }
                    }
                }
            }
        }
    }
}

// MARK: - About Settings Page (UI-7)

struct AboutSettingsPage: View {
    private let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    private let accent = SettingsPage.about.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(icon: "info.circle",
                       title: "About Inertia",
                       description: "Version and support.",
                       accent: accent)

            SettingsPageSection(title: "App", index: 0) {
                SettingsCard(accent: accent) {
                    VStack(spacing: 0) {
                        SettingsRow {
                            HStack {
                                SettingsRowLabel(title: "Version", subtitle: "Installed build of Inertia.")
                                Spacer()
                                Text(version)
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.55))
                            }
                        }
                        SettingsDivider()
                        AboutLinkRow(title: "Contact us",
                                     detail: "Send feedback or report a problem.",
                                     url: URL(string: "mailto:azad.bingi@gmail.com")!,
                                     accent: accent)
                    }
                }
            }
        }
    }
}

private struct AboutLinkRow: View {
    let title: String
    let detail: String
    let url: URL
    let accent: Color

    var body: some View {
        Button { NSWorkspace.shared.open(url) } label: {
            SettingsRow {
                HStack(spacing: 12) {
                    SettingsRowLabel(title: title, subtitle: detail)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(accent.opacity(0.85))
                }
            }
        }
        .buttonStyle(.plain)
    }
}
