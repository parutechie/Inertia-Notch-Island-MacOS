import SwiftUI
import AppKit
import Combine

enum DisplayTarget: String, CaseIterable {
    case main
    case builtIn

    var title: String {
        switch self {
        case .main: return "Main display"
        case .builtIn: return "Built-in display"
        }
    }

    var subtitle: String {
        switch self {
        case .main: return "Follow the active main screen."
        case .builtIn: return "Prefer the built-in MacBook display."
        }
    }

    var symbolName: String {
        switch self {
        case .main: return "display"
        case .builtIn: return "laptopcomputer"
        }
    }

    var screen: NSScreen? {
        switch self {
        case .main:
            return NSScreen.main ?? NotchMetrics.notchScreen
        case .builtIn:
            return NSScreen.screens.first { screen in
                let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
                return number.map { CGDisplayIsBuiltin(CGDirectDisplayID($0.uint32Value)) != 0 } ?? false
            } ?? NotchMetrics.notchScreen
        }
    }
}

enum StatusDisplayStyle: String, CaseIterable, Identifiable {
    case line
    case percent

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

@MainActor
final class FeatureSettings: ObservableObject {
    @Published var displayTarget: DisplayTarget {
        didSet { UserDefaults.standard.set(displayTarget.rawValue, forKey: "displayTarget") }
    }

    @Published var islandWidth: Double {
        didSet { UserDefaults.standard.set(islandWidth, forKey: "islandWidth") }
    }
    @Published var openPanelWidth: Double {
        didSet { UserDefaults.standard.set(openPanelWidth, forKey: "openPanelWidth") }
    }

    @Published var lowBatteryThreshold: Int {
        didSet { UserDefaults.standard.set(lowBatteryThreshold, forKey: "lowBatteryThreshold") }
    }

    @Published var musicPreviewDuration: Double {
        didSet { UserDefaults.standard.set(musicPreviewDuration, forKey: "musicPreviewDuration") }
    }

    @Published var enableSpotifyAppleScriptControl: Bool {
        didSet { UserDefaults.standard.set(enableSpotifyAppleScriptControl, forKey: "enableSpotifyAppleScriptControl") }
    }

    @Published var enableAppleMusicAppleScriptControl: Bool {
        didSet { UserDefaults.standard.set(enableAppleMusicAppleScriptControl, forKey: "enableAppleMusicAppleScriptControl") }
    }

    @Published var enableLockSound: Bool {
        didSet { UserDefaults.standard.set(enableLockSound, forKey: "enableLockSound") }
    }

    @Published var hideNotchWhenFullscreen: Bool {
        didSet { UserDefaults.standard.set(hideNotchWhenFullscreen, forKey: "hideNotchWhenFullscreen") }
    }

    @Published var showFocusAnimations: Bool {
        didSet { UserDefaults.standard.set(showFocusAnimations, forKey: "showFocusAnimations") }
    }

    @Published var focusAnimationDuration: Double {
        didSet { UserDefaults.standard.set(focusAnimationDuration, forKey: "focusAnimationDuration") }
    }

    @Published var hideFocusLabel: Bool {
        didSet { UserDefaults.standard.set(hideFocusLabel, forKey: "hideFocusLabel") }
    }

    @Published var showSoundStatus: Bool {
        didSet { UserDefaults.standard.set(showSoundStatus, forKey: "showSoundStatus") }
    }

    @Published var soundDisplayStyle: StatusDisplayStyle {
        didSet { UserDefaults.standard.set(soundDisplayStyle.rawValue, forKey: "soundDisplayStyle") }
    }

    @Published var soundLineWidth: Double {
        didSet { UserDefaults.standard.set(soundLineWidth, forKey: "soundLineWidth") }
    }

    @Published var showBrightnessStatus: Bool {
        didSet { UserDefaults.standard.set(showBrightnessStatus, forKey: "showBrightnessStatus") }
    }

    @Published var brightnessDisplayStyle: StatusDisplayStyle {
        didSet { UserDefaults.standard.set(brightnessDisplayStyle.rawValue, forKey: "brightnessDisplayStyle") }
    }

    @Published var brightnessLineWidth: Double {
        didSet { UserDefaults.standard.set(brightnessLineWidth, forKey: "brightnessLineWidth") }
    }

    @Published var showNotchEmoji: Bool {
        didSet { UserDefaults.standard.set(showNotchEmoji, forKey: "showNotchEmoji") }
    }

    /// When true the left-wing "emoji" slot shows a looping Lottie animation
    /// (Loader_cat.json bundled in Resources) instead of a text character.
    /// Users can toggle this off to use a custom emoji/text instead.
    @Published var leftEmojiUseLottie: Bool {
        didSet { UserDefaults.standard.set(leftEmojiUseLottie, forKey: "leftEmojiUseLottie") }
    }

    @Published var notchEmoji: String {
        didSet { UserDefaults.standard.set(notchEmoji, forKey: "notchEmoji") }
    }

    @Published var showRightNotchEmoji: Bool {
        didSet { UserDefaults.standard.set(showRightNotchEmoji, forKey: "showRightNotchEmoji") }
    }

    @Published var rightNotchEmoji: String {
        didSet { UserDefaults.standard.set(rightNotchEmoji, forKey: "rightNotchEmoji") }
    }

    @Published var emojiOnlyWhenIdle: Bool {
        didSet { UserDefaults.standard.set(emojiOnlyWhenIdle, forKey: "emojiOnlyWhenIdle") }
    }

    @Published var notchEmojiSize: Double {
        didSet { UserDefaults.standard.set(notchEmojiSize, forKey: "notchEmojiSize") }
    }

    @Published var hudDuration: Double {
        didSet { UserDefaults.standard.set(hudDuration, forKey: "hudDuration") }
    }

    @Published var hudExpansion: Double {
        didSet { UserDefaults.standard.set(hudExpansion, forKey: "hudExpansion") }
    }

    @Published var hudQueueEnabled: Bool {
        didSet { UserDefaults.standard.set(hudQueueEnabled, forKey: "hudQueueEnabled") }
    }

    // MARK: - TASK 2: Intro animation
    @Published var introEnabled: Bool {
        didSet { UserDefaults.standard.set(introEnabled, forKey: "inertia.introEnabled") }
    }
    init() {
        let defaults = UserDefaults.standard
        displayTarget = defaults.string(forKey: "displayTarget").flatMap(DisplayTarget.init(rawValue:)) ?? .builtIn
        islandWidth = defaults.object(forKey: "islandWidth") as? Double ?? 284
        // The open island is intentionally wide and short. Old saved widths were
        // clamped to 560 in a previous build; migrate those to the new default.
        if let saved = defaults.object(forKey: "openPanelWidth") as? Double,
           saved >= IslandLayout.openPanelMinWidth {
            openPanelWidth = min(max(saved, IslandLayout.openPanelMinWidth), IslandLayout.openPanelMaxWidth)
        } else {
            openPanelWidth = IslandLayout.openPanelDefaultWidth
        }
        lowBatteryThreshold = defaults.object(forKey: "lowBatteryThreshold") as? Int ?? 20
        musicPreviewDuration = defaults.object(forKey: "musicPreviewDuration") as? Double ?? 2
        enableSpotifyAppleScriptControl = defaults.object(forKey: "enableSpotifyAppleScriptControl") as? Bool ?? false
        enableAppleMusicAppleScriptControl = defaults.object(forKey: "enableAppleMusicAppleScriptControl") as? Bool ?? false
        enableLockSound = defaults.object(forKey: "enableLockSound") as? Bool ?? true
        hideNotchWhenFullscreen = defaults.object(forKey: "hideNotchWhenFullscreen") as? Bool ?? false
        showFocusAnimations = defaults.object(forKey: "showFocusAnimations") as? Bool ?? true
        focusAnimationDuration = defaults.object(forKey: "focusAnimationDuration") as? Double ?? 2
        hideFocusLabel = defaults.object(forKey: "hideFocusLabel") as? Bool ?? false
        showSoundStatus = defaults.object(forKey: "showSoundStatus") as? Bool ?? true
        soundDisplayStyle = defaults.string(forKey: "soundDisplayStyle").flatMap(StatusDisplayStyle.init(rawValue:)) ?? .line
        soundLineWidth = defaults.object(forKey: "soundLineWidth") as? Double ?? 36
        showBrightnessStatus = defaults.object(forKey: "showBrightnessStatus") as? Bool ?? true
        brightnessDisplayStyle = defaults.string(forKey: "brightnessDisplayStyle").flatMap(StatusDisplayStyle.init(rawValue:)) ?? .line
        brightnessLineWidth = defaults.object(forKey: "brightnessLineWidth") as? Double ?? 36
        showNotchEmoji = defaults.object(forKey: "showNotchEmoji") as? Bool ?? true
        leftEmojiUseLottie = defaults.object(forKey: "leftEmojiUseLottie") as? Bool ?? true
        notchEmoji = defaults.string(forKey: "notchEmoji") ?? "🤍"
        showRightNotchEmoji = defaults.object(forKey: "showRightNotchEmoji") as? Bool ?? false
        rightNotchEmoji = defaults.string(forKey: "rightNotchEmoji") ?? "✨"
        emojiOnlyWhenIdle = defaults.object(forKey: "emojiOnlyWhenIdle") as? Bool ?? true
        notchEmojiSize = defaults.object(forKey: "notchEmojiSize") as? Double ?? 15
        hudDuration = defaults.object(forKey: "hudDuration") as? Double ?? 2
        hudExpansion = defaults.object(forKey: "hudExpansion") as? Double ?? 8
        hudQueueEnabled = defaults.object(forKey: "hudQueueEnabled") as? Bool ?? true
        // TASK 2
        introEnabled = defaults.object(forKey: "inertia.introEnabled") as? Bool ?? true
    }

    func resetGeneral() {
        islandWidth = 284
        openPanelWidth = IslandLayout.openPanelDefaultWidth
        displayTarget = .builtIn
        enableLockSound = true
        hideNotchWhenFullscreen = false
        showNotchEmoji = true
        leftEmojiUseLottie = true
        notchEmoji = "🤍"
        showRightNotchEmoji = false
        rightNotchEmoji = "✨"
        emojiOnlyWhenIdle = true
        notchEmojiSize = 15
        lowBatteryThreshold = 20
    }

    func resetFocus() {
        showFocusAnimations = true
        focusAnimationDuration = 2
        hideFocusLabel = false
    }

    func resetSound() {
        showSoundStatus = true
        soundDisplayStyle = .line
        soundLineWidth = 36
    }

    func resetBrightness() {
        showBrightnessStatus = true
        brightnessDisplayStyle = .line
        brightnessLineWidth = 36
    }

    func resetBattery() {
        lowBatteryThreshold = 20
    }

    func resetMusic() {
        musicPreviewDuration = 2
        enableSpotifyAppleScriptControl = false
        enableAppleMusicAppleScriptControl = false
    }

    // TASK 2
    func resetIntro() {
        introEnabled = true
    }
}
