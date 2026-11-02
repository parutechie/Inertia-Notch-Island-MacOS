import Foundation

struct SettingsSearchItem: Identifiable, Hashable {
    let id: String
    let page: SettingsPage
    let title: String
    let subtitle: String?
    let keywords: [String]
}

enum SettingsCatalog {
    static let groups: [(title: String?, pages: [SettingsPage])] = [
        (nil, [.general]),
        ("Notifications", [.focus, .sound, .battery]),
        ("Live Activities", [.music, .calendar]),
        // UI-7: this group only holds Permissions, so it is named System.
        ("System", [.permissions]),
        ("Inertia", [.about])
    ]

    static let items: [SettingsSearchItem] = [
        item("display", .general, "Display",
             "Choose where Inertia appears.", "main", "built-in", "screen", "monitor"),
        item("island-width", .general, "Island Width",
             "Set the base width used by the dynamic island.", "notch", "size", "width"),
        item("hud-duration", .general, "HUD duration",
             "How long live status updates stay visible.", "timing", "dwell", "status", "volume", "charging"),
        item("hud-expansion", .general, "HUD expansion",
             "Extend live status HUDs slightly below the notch.", "expand", "height", "status"),
        item("hud-queue", .general, "Queue status updates",
             "Show live status changes one after another instead of replacing each other.", "queue", "hud"),
        item("launch-at-login", .general, "Launch at Login",
             "Open Inertia automatically when you sign in.", "startup", "login"),
        item("hide-fullscreen", .general, "Hide in Fullscreen",
             "Hide the island while the active app is fullscreen.", "fullscreen", "hide"),
        item("network-status", .general, "Network Status",
             "Show Wi-Fi, Personal Hotspot, and internet availability changes.", "wifi", "internet", "offline"),
        item("unlock-sound", .general, "Unlock Sound",
             "Play a subtle sound when your Mac unlocks.", "lock", "sound", "login"),
        item("left-emoji", .general, "Left emoji",
             "Show a customizable character on the left side of the island.", "character", "notch"),
        item("left-emoji-character", .general, "Left character",
             "Use an emoji or a short symbol on the left side.", "left emoji", "character", "notch"),
        item("left-emoji-lottie", .general, "Left Lottie animation",
             "Show an animated Lottie loader instead of a character on the left side.", "lottie", "animation", "notch", "loader", "cat"),
        item("right-emoji", .general, "Right emoji",
             "Show a customizable character on the right side of the island.", "character", "notch"),
        item("right-emoji-character", .general, "Right character",
             "Use an emoji or a short symbol on the right side.", "right emoji", "character", "notch"),
        item("emoji-idle", .general, "Emoji only when idle",
             "Hide emoji while music, meetings, Focus, privacy, or live statuses are active.", "hide", "activity"),
        item("emoji-size", .general, "Emoji size",
             "Adjust how large the emoji appears.", "character", "size"),
        item("alert-sounds", .general, "Alert Sounds",
             "Play a chime when a reminder or focus timer fires.", "sound", "chime"),
        item("speak-reminders", .general, "Speak Reminders",
             "Read reminder titles aloud using your system voice.", "voice", "speech"),
        item("system-notifications", .general, "System Notification Banners",
             "Also send a standard macOS banner when a reminder fires.", "notifications", "alerts"),
        item("privacy-indicators", .general, "Privacy Indicators",
             "Show microphone, camera and screen-share status beside the notch.", "camera", "microphone", "screen"),
        item("clipboard-history", .general, "Clipboard History",
             "Keep text, links, images and files you copy on the Shelf.", "copy", "paste", "shelf"),
        item("battery-alerts-general", .general, "Charging & Battery Alerts",
             "Notify when power is connected, low, or full.", "power", "charging"),
        item("network-alerts", .general, "Network Alerts",
             "Notify when you go offline or come back online.", "wifi", "internet"),
        item("animation-speed", .general, "Animation Speed",
             "Set the island animation speed multiplier.", "motion", "spring"),

        // TASK 2: intro search entries
        item("intro-enabled", .general, "Play intro on launch",
             "Show the handwritten hello when Inertia starts.", "hello", "animation", "launch", "greeting"),
        item("intro-preview", .general, "Preview intro",
             "Play the intro animation right now.", "hello", "animation", "greeting"),
        item("hello-animation", .general, "Hello animation",
             "Apple-style handwritten hello plays on launch.", "hello", "handwriting", "intro"),

        item("focus-animation", .focus, "Focus animation",
             "Show a small island animation when Focus turns on or off.", "do not disturb", "dnd"),
        item("focus-duration", .focus, "Focus animation duration",
             "How long the Focus status stays visible.", "timing", "dwell"),
        item("focus-label", .focus, "Hide Focus label",
             "Hide the On or Off label on the right side of the island.", "text"),

        item("sound-status", .sound, "Sound status",
             "Show a small island status when you change output volume manually.", "volume", "speaker"),
        item("sound-style", .sound, "Sound display style",
             "Choose either a compact line or a numeric percentage.", "volume", "line", "percent"),
        item("sound-line-width", .sound, "Sound line width",
             "Adjust how much room the sound line uses.", "volume", "meter"),

        item("battery-alerts", .battery, "Battery alerts",
             "Notify when power is connected, low, or full.", "charging", "power"),
        item("low-battery", .battery, "Low battery threshold",
             "Warn when the battery drops to this level.", "percent", "power"),
        item("battery-in-notch", .battery, "Battery in notch",
             "Show battery percentage in the collapsed island.", "battery", "level", "show"),

        item("brightness-status", .brightness, "Brightness",
             "Show island status when you change display brightness.", "sun.max", "brightness", "hud"),
        item("brightness-style", .brightness, "Brightness display style",
             "Choose either a line or percentage for brightness HUDs.", "sun.max", "line", "percent"),
        item("brightness-line-width", .brightness, "Brightness line width",
             "Adjust how much room the brightness line uses.", "sun.max", "slider"),

        item("music-notch", .music, "Show music in the notch",
             "Show the app icon and live equalizer while something plays.", "now playing", "track"),
        item("track-peek", .music, "Peek when track changes",
             "Briefly widen the notch to show the new song title.", "now playing", "song"),
        item("lyrics", .music, "Synced lyrics",
             "Fetch time-synced lyrics from LRCLIB and follow the current line.", "song", "words"),
        item("preview-duration", .music, "Preview duration",
             "How long the track title stays visible when the song changes.", "timing", "track"),
        item("precise-mode", .music, "Precise Browser Mode",
             "Read real play state, artist and artwork from browser tabs.", "chrome", "safari", "browser", "youtube"),

        item("calendar-access", .calendar, "Calendar access",
             "Connect Apple Calendar to Inertia.", "events", "schedule"),
        item("calendar-alerts", .calendar, "Upcoming event alerts",
             "Show a notch alert five minutes before an event starts.", "events", "meetings"),
        item("local-events", .calendar, "Local events",
             "Events stored only on this Mac while Calendar access is unavailable.", "offline", "events"),

        item("automation", .permissions, "Automation",
             "Allow players and browsers to be controlled from Inertia.", "spotify", "music", "browser"),
        item("accessibility", .permissions, "Accessibility",
             "Send media key events when a player cannot be scripted directly.", "permission"),
        item("notification-permission", .permissions, "Notifications permission",
             "Show standard macOS banners for reminders.", "alerts"),
        item("calendar-permission", .permissions, "Calendar permission",
             "Read your schedule and add events.", "events"),
        item("recheck-permissions", .permissions, "Re-check permissions",
             "Refresh the permission status for every app.", "refresh"),

        item("version", .about, "Version",
             "See the installed Inertia version.", "update", "release"),
        item("contact", .about, "Contact",
             "Email Inertia support.", "support", "email", "help")
    ]

    static func search(_ query: String) -> [SettingsSearchItem] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return [] }

        return items
            .compactMap { item -> (SettingsSearchItem, Int)? in
                let title = item.title
                let rank: Int
                if title.compare(needle, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame {
                    rank = 0
                } else if title.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive, .anchored]) != nil {
                    rank = 1
                } else if title.localizedCaseInsensitiveContains(needle) {
                    rank = 2
                } else if (item.subtitle ?? "").localizedCaseInsensitiveContains(needle) {
                    rank = 3
                } else if item.keywords.contains(where: { $0.localizedCaseInsensitiveContains(needle) })
                            || item.page.title.localizedCaseInsensitiveContains(needle) {
                    rank = 4
                } else {
                    return nil
                }
                return (item, rank)
            }
            .enumerated()
            .sorted { lhs, rhs in
                lhs.element.1 == rhs.element.1
                    ? lhs.offset < rhs.offset
                    : lhs.element.1 < rhs.element.1
            }
            .map { $0.element.0 }
    }

    static func matchCount(for page: SettingsPage, in results: [SettingsSearchItem]) -> Int {
        results.lazy.filter { $0.page == page }.count
    }

    private static func item(_ id: String, _ page: SettingsPage, _ title: String,
                             _ subtitle: String?, _ keywords: String...) -> SettingsSearchItem {
        SettingsSearchItem(id: id, page: page, title: title, subtitle: subtitle, keywords: keywords)
    }
}
