import SwiftUI
import Combine
import AVFoundation
import ServiceManagement
import UserNotifications

enum IslandMode { case collapsed, open, alert }

enum FocusPhase: String, Codable {
    case work, shortBreak, longBreak
    var isBreak: Bool { self != .work }
    var title: String {
        switch self {
        case .work: return "FOCUS"
        case .shortBreak: return "SHORT BREAK"
        case .longBreak: return "LONG BREAK"
        }
    }
    var icon: String {
        switch self {
        case .work: return "timer"
        case .shortBreak: return "cup.and.saucer.fill"
        case .longBreak: return "figure.walk"
        }
    }
}

enum IslandTab: String, CaseIterable, Identifiable {
    case launcher, tasks, notes, remind, music, focus, shelf, calendar, settings
    var id: String { rawValue }

    /// FIX 1: canonical left-to-right order of tabs shown in the header capsule.
    /// Launcher is last before "…"; .settings is a real tab too.
    static let headerOrder: [IslandTab] = [
        .tasks, .notes, .remind, .music, .focus, .shelf, .calendar, .settings, .launcher
    ]
    var title: String {
        switch self {
        case .launcher: return "Launcher"
        case .tasks: return "Tasks"
        case .notes: return "Notes"
        case .remind: return "Reminders"
        case .music: return "Music"
        case .focus: return "Focus"
        case .shelf: return "Shelf"
        case .calendar: return "Calendar"
        case .settings: return "Settings"
        }
    }
    var icon: String {
        switch self {
        case .launcher: return "square.grid.2x2.fill"
        case .tasks: return "checklist"
        case .notes: return "note.text"
        case .remind: return "bell.fill"
        case .music: return "music.note"
        case .focus: return "timer"
        case .shelf: return "tray.full.fill"
        case .calendar: return "calendar"
        case .settings: return "gearshape.fill"
        }
    }
    var tint: Color {
        switch self {
        case .launcher: return Color(red: 0.45, green: 0.66, blue: 1.00)
        case .tasks: return Color(red: 0.35, green: 0.95, blue: 0.80)
        case .notes: return Color(red: 1.00, green: 0.72, blue: 0.45)
        case .remind: return Color(red: 0.70, green: 0.55, blue: 1.00)
        case .music: return Color(red: 1.00, green: 0.42, blue: 0.62)
        case .focus: return Color(red: 0.40, green: 0.75, blue: 1.00)
        case .shelf: return Color(red: 0.55, green: 0.85, blue: 1.00)
        case .calendar: return Color(red: 0.98, green: 0.62, blue: 0.45)
        case .settings: return Color(red: 0.30, green: 0.83, blue: 0.82)
        }
    }
}

enum SettingsPage: String, CaseIterable, Identifiable, Hashable {
    case general, focus, sound, brightness, battery, audio, music, calendar, permissions, about
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

// MARK: - Models
struct TodoItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var done = false
    var prio = 1
}

struct Note: Identifiable, Codable, Equatable {
    var id = UUID()
    var text = ""
    var color = 0
    var pinned = false
    var updated = Date()

    init() {}
    // Old saved notes only had id + text, so every new field is optional when decoding.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
        color = try c.decodeIfPresent(Int.self, forKey: .color) ?? 0
        pinned = try c.decodeIfPresent(Bool.self, forKey: .pinned) ?? false
        updated = try c.decodeIfPresent(Date.self, forKey: .updated) ?? Date()
    }
    var lines: [String] {
        text.split(separator: "\n", omittingEmptySubsequences: true).map { String($0).trimmingCharacters(in: .whitespaces) }
    }
    var title: String { lines.first ?? "New note" }
    var preview: String { lines.dropFirst().joined(separator: " ") }
}

enum RemindKind: String, Codable, CaseIterable {
    case once, daily, days
    var label: String { rawValue.capitalized }
}

struct Reminder: Identifiable, Codable {
    var id = UUID()
    var title: String
    var kind: RemindKind = .once
    var time: Date
    var date: Date
    var days: [Int] = []
    var active = true
    var sound = true
}

extension Reminder {
    func nextOccurrence(after ref: Date = Date()) -> Date? {
        let cal = Calendar.current
        let c = cal.dateComponents([.hour, .minute], from: time)
        switch kind {
        case .once, .daily:
            return cal.nextDate(after: ref, matching: c, matchingPolicy: .nextTime)
        case .days:
            return days.compactMap { d -> Date? in
                var dc = c; dc.weekday = d
                return cal.nextDate(after: ref, matching: dc, matchingPolicy: .nextTime)
            }.min()
        }
    }
    var summary: String {
        switch kind {
        case .once: return date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        case .daily: return "Every day"
        case .days:
            if days.count == 7 { return "Every day" }
            if Set(days) == [2, 3, 4, 5, 6] { return "Weekdays" }
            if Set(days) == [1, 7] { return "Weekends" }
            return days.sorted().map { Calendar.current.shortWeekdaySymbols[$0 - 1] }.joined(separator: " · ")
        }
    }
}

func countdown(to target: Date) -> String {
    let s = Int(target.timeIntervalSinceNow)
    if s <= 0 { return "now" }
    let m = (s + 59) / 60
    if m < 60 { return "in \(m)m" }
    let h = m / 60
    if h < 24 { return m % 60 == 0 ? "in \(h)h" : "in \(h)h \(m % 60)m" }
    let days = h / 24
    return "in \(days) day\(days == 1 ? "" : "s")"
}

struct NowPlaying: Equatable {
    var app: String? = nil          // "Google Chrome", "Spotify", "System audio"
    var bundleID: String? = nil     // used to show the real app / browser logo
    var native = false              // Music / Spotify (scriptable)
    var browser = false
    var playing = false
    var precise = false             // true = real play state, not guessed from audio output
    var title = ""
    var artist = ""
    var source = ""                 // "YouTube Music", "Netflix" ...
    var artwork: URL? = nil
    var position: Double = 0
    var duration: Double = 0
}

struct AlertInfo {
    var title: String
    var subtitle = "Right now"
    var icon = "bell.fill"
    var tint = IslandTab.remind.tint
    var snooze = false
    var sticky = true
    var until = Date()
    var speak = true
    var joinURL: URL? = nil
}

struct Meeting: Identifiable, Equatable {
    var id = UUID()
    var name: String
    var bundleID: String
    var web: Bool = false
    var started: Date = Date()
    var muted: Bool? = nil      // nil = unknown, true = muted, false = live
    var canMute: Bool = false
    var pid: pid_t = 0
}

func clock(_ s: Int) -> String { String(format: "%02d:%02d", s / 60, s % 60) }

// MARK: - Store
final class Store: ObservableObject {
    static let shared = Store()

    @Published var showMenu = false
    @Published var mode = IslandMode.collapsed
    // FIX 1: default tab is .tasks; .launcher is only shown explicitly.
    @Published var tab = IslandTab.tasks
    // TASK 3: keyboard lock state (never persisted)
    @Published var keyboardLocked = false
    // TASK 3: island hidden state (never persisted)
    @Published var islandHidden = false
    // TASK 2: intro animation state (never persisted)
    @Published var introActive = false
    @Published var settingsPage = SettingsPage.general
    @Published var launcherPins: [LauncherTool] = Store.loadLauncherPins() {
        didSet { Store.saveLauncherPins(launcherPins) }
    }
    @Published var todos: [TodoItem] = Store.load("todos2") { didSet { Store.save(todos, "todos2") } }
    @Published var notes: [Note] = Store.load("notes") { didSet { Store.save(notes, "notes") } }
    @Published var reminders: [Reminder] = Store.load("reminders2") { didSet { Store.save(reminders, "reminders2") } }
    @Published var alertInfo: AlertInfo?
    @Published var liveStatus: LiveStatus?
    @Published var isFullscreenActive = false
    @Published var isScreenLocked = false

    let featureSettings = FeatureSettings()
    let networkCenter = NetworkStatusCenter()
    private var liveStatusTask: Task<Void, Never>?
    private var liveStatusQueue: [(status: LiveStatus, duration: TimeInterval)] = []
    private var featuresStarted = false
    var networkMonitoringActive = false

    @Published var meeting: Meeting? = nil
    @Published var meetingShown: Bool = false
    @Published var meetingHint: String? = nil

    // Focus
    @Published var phase = FocusPhase.work
    @Published var workMin = Store.int("workMin", 25) {
        didSet { UserDefaults.standard.set(workMin, forKey: "workMin"); if !focusRunning && phase == .work { focusLeft = workMin * 60 } }
    }
    @Published var breakMin = Store.int("breakMin", 5) {
        didSet { UserDefaults.standard.set(breakMin, forKey: "breakMin"); if !focusRunning && phase == .shortBreak { focusLeft = breakMin * 60 } }
    }
    @Published var longBreakMin = Store.int("longBreakMin", 15) {
        didSet { UserDefaults.standard.set(longBreakMin, forKey: "longBreakMin"); if !focusRunning && phase == .longBreak { focusLeft = longBreakMin * 60 } }
    }
    @Published var sessionsBeforeLong = Store.int("sessionsBeforeLong", 4) { didSet { UserDefaults.standard.set(sessionsBeforeLong, forKey: "sessionsBeforeLong") } }
    @Published var autoStartBreaks = Store.bool("autoStartBreaks", true) { didSet { Store.setBool(autoStartBreaks, "autoStartBreaks") } }
    @Published var autoStartFocus = Store.bool("autoStartFocus", false) { didSet { Store.setBool(autoStartFocus, "autoStartFocus") } }
    @Published var focusLeft = Store.int("workMin", 25) * 60
    @Published var focusRunning = false
    @Published var sessions = 0
    @Published var focusSessionsToday = Store.int("focusSessionsToday", 0) { didSet { UserDefaults.standard.set(focusSessionsToday, forKey: "focusSessionsToday") } }
    @Published var focusSecondsToday = Store.int("focusSecondsToday", 0) { didSet { UserDefaults.standard.set(focusSecondsToday, forKey: "focusSecondsToday") } }
    @Published var keepAwake = false { didSet { setAwake() } }

    // Preferences
    @Published var showMusicInNotch = Store.bool("showMusicInNotch", true) {
        didSet { Store.setBool(showMusicInNotch, "showMusicInNotch"); if !showMusicInNotch { peek = false } }
    }
    @Published var trackPeek = Store.bool("trackPeek", true) { didSet { Store.setBool(trackPeek, "trackPeek") } }
    /// Animation speed multiplier. 1.0 = default, 0.5 = slow, 2.0 = fast.
    @Published var animSpeed: Double = Store.double("animSpeed", 1.0) {
        didSet { UserDefaults.standard.set(animSpeed, forKey: "animSpeed") }
    }
    @Published var alertSounds = Store.bool("alertSounds", true) { didSet { Store.setBool(alertSounds, "alertSounds") } }
    @Published var speakReminders = Store.bool("speakReminders", true) { didSet { Store.setBool(speakReminders, "speakReminders") } }
    @Published var systemNotifications = Store.bool("sysNotif", false) {
        didSet {
            Store.setBool(systemNotifications, "sysNotif")
            if systemNotifications && !notifAuthorized { requestNotifications() }
        }
    }
    @Published var launchAtLogin = (SMAppService.mainApp.status == .enabled) {
        didSet {
            do {
                if launchAtLogin { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch { NSLog("Inertia: launch at login failed: \(error)") }
        }
    }

    // Media + permissions (logic lives in MediaEngine.swift)
    @Published var playing = NowPlaying() {
        didSet {
            NSLog("INERTIA music playing: app=\(playing.app ?? "nil") title=\(playing.title) playing=\(playing.playing) precise=\(playing.precise) browser=\(playing.browser) native=\(playing.native)")
        }
    }
    @Published var peek = false {
        didSet { NSLog("INERTIA music peek: \(peek) until=\(peekUntil)") }
    }
    @Published var mediaHint: String?
    @Published var perms: [String: PermState] = [:]
    @Published var jsReady: [String: Bool] = [:]
    @Published var axTrusted = AXIsProcessTrusted()
    @Published var notifAuthorized = false

    // Lyrics (LyricsEngine.swift)
    @Published var lyrics = LyricsResult()
    @Published var showLyrics = Store.bool("showLyrics", true) {
        didSet {
            Store.setBool(showLyrics, "showLyrics")
            if showLyrics, playing.app != nil { fetchLyrics(for: playing) }
            else if !showLyrics { lyrics = LyricsResult(status: .off) }
        }
    }

    // Privacy dots (PrivacyMonitor.swift)
    @Published var micInUse = false
    @Published var micAppName: String? = nil
    @Published var micAppBundleID: String? = nil
    @Published var cameraInUse = false
    @Published var cameraAppName: String? = nil
    @Published var cameraAppBundleID: String? = nil
    @Published var screenSharing = false
    @Published var screenAppName: String? = nil
    @Published var screenAppBundleID: String? = nil
    @Published var privacySince: Date? = nil
    @Published var showPrivacyIndicators = Store.bool("showPrivacyIndicators", true) {
        didSet { Store.setBool(showPrivacyIndicators, "showPrivacyIndicators") }
    }
    var privacyTimerRunning = false

    // Clipboard shelf
    @Published var clipboardEnabled = Store.bool("clipboardEnabled", true) {
        didSet { Store.setBool(clipboardEnabled, "clipboardEnabled") }
    }

    // Battery + network (SystemStatus.swift)
    @Published var battery: BatteryState? = nil
    @Published var network: NetworkState? = nil
    @Published var showNetworkInNotch = Store.bool("showNetworkInNotch", true) {
        didSet { Store.setBool(showNetworkInNotch, "showNetworkInNotch") }
    }
    @Published var batteryAlerts = Store.bool("batteryAlerts", true) {
        didSet { Store.setBool(batteryAlerts, "batteryAlerts") }
    }
    @Published var showBatteryInNotch = Store.bool("showBatteryInNotch", false) {
        didSet { Store.setBool(showBatteryInNotch, "showBatteryInNotch") }
    }
    @Published var networkAlerts = Store.bool("networkAlerts", true) {
        didSet { Store.setBool(networkAlerts, "networkAlerts") }
    }
    @Published var calendarAlerts = Store.bool("calendarAlerts", true) {
        didSet { Store.setBool(calendarAlerts, "calendarAlerts") }
    }
    var batteryWasPlugged: Bool? = nil
    var batteryWasCharging = false
    var batteryFullWarned = false
    var lowBatteryWarned: Set<Int> = []
    var networkWasConnected: Bool? = nil

    // Meetings (disabled)
    var meetingTimerRunning = false
    var meetingNoMicTicks = 0

    // Calendar reminders
    private var notifiedEventIDs: Set<String> = []
    private var focusStatsDay = Store.string("focusStatsDay", "")

    var focusTotal: Int { (phase == .work ? workMin : phase == .shortBreak ? breakMin : longBreakMin) * 60 }
    var sessionsUntilLongBreak: Int {
        let n = sessionsBeforeLong <= 0 ? 1 : sessionsBeforeLong
        let left = n - (sessions % n)
        return left == n && sessions > 0 ? n : left
    }
    var privacyActive: Bool { showPrivacyIndicators && (micInUse || cameraInUse || screenSharing) }
    var emojiIdle: Bool {
        !musicShown && !focusVisible && !privacyActive && liveStatus == nil &&
        !(showNetworkInNotch && network?.connected == false)
    }
    var showsLeftEmoji: Bool {
        featureSettings.showNotchEmoji && (!featureSettings.emojiOnlyWhenIdle || emojiIdle)
    }
    var showsRightEmoji: Bool {
        featureSettings.showRightNotchEmoji && (!featureSettings.emojiOnlyWhenIdle || emojiIdle)
    }
    var hitSize = CGSize(width: 150, height: 32)

    // Media bookkeeping (main-thread unless noted)
    let scriptQ = DispatchQueue(label: "inertia.scripts")   // all AppleScript runs here
    var mediaBusy = false
    var holdUntil = Date.distantPast
    var holdValue = false
    var mediaTab: TabRef?
    var lastTrackKey = ""
    var peekUntil = Date.distantPast
    /// Timestamp of the last poll that reported media as playing. Used by the
    /// detection-hysteresis in `applyMedia` to keep `playing.playing` latched
    /// for a grace period, preventing the music notch from collapsing after
    /// ~3 s when a single poll reports "not playing" due to unreliable
    /// detection (browser tabs without Precise JS, transient AppleScript
    /// errors, or audio-device flag lag).
    var lastPlayingAt = Date.distantPast
    /// Grace period (seconds) during which a "not playing" detection result is
    /// overridden if we were recently playing.
    static let mediaGracePeriod: TimeInterval = 5
    var meetNoSignalCount = 0
    var meetBusy = false

    private var awake: NSObjectProtocol?
    private let voice = AVSpeechSynthesizer()
    private var ticks = 0

    /// Music icon + equalizer visible in the collapsed notch?
    var musicShown: Bool { showMusicInNotch && playing.app != nil && (playing.playing || peek) }
    /// Focus timer visible in the collapsed notch, including paused / break states.
    var focusVisible: Bool { focusRunning || focusLeft < focusTotal || phase != .work }

    var privacyIndicatorCount: Int {
        [micInUse, cameraInUse, screenSharing].filter { $0 }.count
    }

    /// Width the collapsed left wing needs for its emoji, artwork/focus icon
    /// and privacy indicators, including a gap before the notch cutout.
    var collapsedLeftContentWidth: CGFloat {
        IslandLayout.collapsedLeftWidth(
            emoji: showsLeftEmoji,
            music: musicShown,
            focus: focusVisible,
            privacyCount: privacyActive ? privacyIndicatorCount : 0
        )
    }

    /// Width the collapsed right wing needs for its now-playing/status content.
    var collapsedRightContentWidth: CGFloat {
        guard mode == .collapsed else { return 0 }
        var content: CGFloat = 0
        var items = 0
        if peek && musicShown { content += 150; items += 1 }
        else if focusVisible { content += 52; items += 1 }
        else if musicShown { content += 18; items += 1 }
        if showBatteryInNotch, battery?.present == true { content += 72; items += 1 }
        if showNetworkInNotch, network?.connected == false { content += 18; items += 1 }
        if keyboardLocked { content += 12; items += 1 }
        if showsRightEmoji { content += IslandLayout.collapsedEmojiWidth; items += 1 }
        guard items > 0 else { return 0 }
        return IslandLayout.collapsedWingInset + IslandLayout.collapsedWingNotchGap
            + content + CGFloat(items - 1) * IslandLayout.collapsedWingSpacing
    }

    /// How much wider than the physical notch the collapsed island is.
    var wing: CGFloat {
        guard mode == .collapsed else { return 0 }
        let networkDown = showNetworkInNotch && network?.connected == false
        let status: CGFloat = networkDown ? 58 : 0
        let privacy: CGFloat = privacyActive
            ? IslandLayout.privacyIndicatorsWidth(privacyIndicatorCount) + 14
            : 0
        let emojiCount = (showsLeftEmoji ? 1 : 0) + (showsRightEmoji ? 1 : 0)
        let emojiSize = CGFloat(featureSettings.notchEmojiSize)
        let emoji: CGFloat = emojiCount == 0
            ? 0
            : max(54, emojiSize * 2 + 22 + CGFloat(emojiCount - 1) * 28)
        let batteryWidth: CGFloat = (showBatteryInNotch && battery?.present == true) ? 72 : 0

        let base: CGFloat
        // UI-1: tighter padding for collapsed notch. Base widths now minimal:
        // - peek+music: 250 → keep (track peek needs more room for title marquee)
        // - music+focus: 140 → reduce to 100
        // - music only: 80 → reduce to 50 (artwork + small equalizer fit in 40pt wing)
        // - focus only: 120 → reduce to 70 (focus icon needs less space)
        // - privacy only: 68 → reduce to 55
        if peek && musicShown { base = 250 }
        else if musicShown && focusVisible { base = 100 }
        else if musicShown { base = 50 }
        else if focusVisible { base = 70 }
        else if privacyActive { base = 55 }
        else { base = 2 * IslandLayout.collapsedMinPadH }
        let content = base + status + privacy + emoji + batteryWidth
        // Never let a wing be narrower than its actual content: with privacy
        // indicators present the left wing needs to grow with the icon count.
        let minimum = collapsedLeftContentWidth + collapsedRightContentWidth
        let total = liveStatus == nil ? content : max(content, 90)
        return max(total, minimum)
    }

    init() {
        resetDailyFocusStatsIfNeeded()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer, forMode: .common)   // keeps ticking while menus are open
        refreshPermissions()
        startPrivacyMonitor()
        refreshSystemStatus()
        CalendarEngine.shared.start()
        _ = ClipboardManager.shared
    }

    static func int(_ k: String, _ d: Int) -> Int { (UserDefaults.standard.object(forKey: k) as? Int) ?? d }
    static func bool(_ k: String, _ d: Bool) -> Bool { (UserDefaults.standard.object(forKey: k) as? Bool) ?? d }
    static func setBool(_ v: Bool, _ k: String) { UserDefaults.standard.set(v, forKey: k) }
    static func double(_ k: String, _ d: Double) -> Double { (UserDefaults.standard.object(forKey: k) as? Double) ?? d }
    static func string(_ k: String, _ d: String) -> String { (UserDefaults.standard.object(forKey: k) as? String) ?? d }
    static var dayKey: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
    static func load<T: Codable>(_ key: String) -> [T] {
        guard let d = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([T].self, from: d)) ?? []
    }
    static func save<T: Codable>(_ v: [T], _ key: String) {
        if let d = try? JSONEncoder().encode(v) { UserDefaults.standard.set(d, forKey: key) }
    }

    static func loadLauncherPins() -> [LauncherTool] {
        let defaults = UserDefaults.standard
        guard let raw = defaults.array(forKey: "launcherPins") as? [String] else {
            return LauncherTool.defaultPins
        }
        // TASK 1 migration: drop unknown/removed raw values with compactMap.
        let cleaned = raw.compactMap(LauncherTool.init(rawValue:))
        if cleaned.isEmpty { return LauncherTool.defaultPins }
        // Persist the cleaned list so removed values are gone for good.
        defaults.set(cleaned.map(\.rawValue), forKey: "launcherPins")
        return cleaned
    }

    static func saveLauncherPins(_ pins: [LauncherTool]) {
        UserDefaults.standard.set(pins.map(\.rawValue), forKey: "launcherPins")
    }

    // MARK: loop
    private func tick() {
        if focusRunning {
            focusLeft -= 1
            if focusLeft <= 0 { finishPhase() }
        }
        if let a = alertInfo, mode == .alert, !a.sticky, Date() >= a.until { dismissAlert() }
        if mode != .alert, let r = reminders.first(where: { $0.active && $0.date <= Date() }) { fire(r) }
        if peek && Date() >= peekUntil { peek = false }

        ticks += 1
        let musicOpen = mode == .open && tab == .music
        if musicOpen || showMusicInNotch, ticks % (musicOpen ? 1 : 2) == 0 { refreshMusic() }
        if ticks % 6 == 0, (musicOpen || showMusicInNotch || (mode == .open && tab == .settings)) { refreshPermissions() }
        if ticks % 20 == 0 { refreshSystemStatus() }
        if ticks % 15 == 0 { checkCalendarReminders() }
        if ticks % 45 == 0 { resetDailyFocusStatsIfNeeded() }
    }

    // MARK: live status
    func showLiveStatus(_ status: LiveStatus, duration: TimeInterval? = nil) {
        let dwell = duration ?? featureSettings.hudDuration

        guard let current = liveStatus else {
            presentLiveStatus(status, duration: dwell)
            return
        }

        if current.kind == status.kind {
            liveStatusQueue.removeAll { $0.status.kind == status.kind }
            presentLiveStatus(status, duration: dwell)
            return
        }

        guard featureSettings.hudQueueEnabled else {
            liveStatusQueue.removeAll()
            presentLiveStatus(status, duration: dwell)
            return
        }

        if let index = liveStatusQueue.firstIndex(where: { $0.status.kind == status.kind }) {
            liveStatusQueue[index] = (status, dwell)
        } else {
            liveStatusQueue.append((status, dwell))
            if liveStatusQueue.count > 4 { liveStatusQueue.removeFirst() }
        }
    }

    func hideLiveStatus() {
        liveStatusTask?.cancel()
        liveStatusTask = nil
        liveStatusQueue.removeAll()
        guard liveStatus != nil else { return }
        withAnimation(.easeOut(duration: 0.22)) { liveStatus = nil }
    }

    private func presentLiveStatus(_ status: LiveStatus, duration: TimeInterval) {
        liveStatusTask?.cancel()
        if liveStatus != status {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) { liveStatus = status }
        }
        liveStatusTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            self?.advanceLiveStatus()
        }
    }

    private func advanceLiveStatus() {
        liveStatusTask?.cancel()
        liveStatusTask = nil
        guard !liveStatusQueue.isEmpty else {
            withAnimation(.easeOut(duration: 0.22)) { liveStatus = nil }
            return
        }
        let next = liveStatusQueue.removeFirst()
        presentLiveStatus(next.status, duration: next.duration)
    }

    func handleSystemFocusChange(_ active: Bool) {
        guard featureSettings.showFocusAnimations else { return }
        showLiveStatus(.focus(active), duration: featureSettings.focusAnimationDuration)
    }

    func startFeatures() {
        guard !featuresStarted else { return }
        featuresStarted = true
        SystemControlCenter.shared.start()
        SystemFocusMonitor.shared.start()
        networkCenter.onEvent = { [weak self] event in self?.handleNetworkEvent(event) }
        networkCenter.onStateChange = { [weak self] state in
            self?.network = state
            self?.networkWasConnected = state.connected
        }
        networkCenter.start()
        FullscreenMonitor.shared.onChange = { [weak self] active in
            self?.isFullscreenActive = active
        }
        FullscreenMonitor.shared.start()
        LockScreenMonitor.shared.start()
        networkMonitoringActive = true
    }

    func handleNetworkEvent(_ event: NetworkStatusEvent) {
        guard networkAlerts else { return }
        notify(AlertInfo(title: event.title,
                         subtitle: event.subtitle,
                         icon: event.icon,
                         tint: event.tint,
                         snooze: false,
                         sticky: false,
                         until: Date().addingTimeInterval(4.5),
                         speak: false))
    }

    // MARK: notch notifications
    func notify(_ a: AlertInfo) {
        alertInfo = a
        mode = .alert
        if alertSounds { NSSound(named: a.sticky ? "Glass" : "Pop")?.play() }
        if a.speak && speakReminders { voice.speak(AVSpeechUtterance(string: a.title)) }
        // Only send a system notification as a FALLBACK when the notch cannot
        // show the alert (island hidden or a fullscreen app is active). This
        // prevents every alert from appearing in both the notch card and a
        // macOS notification banner at the same time.
        if a.sticky, islandHidden || isFullscreenActive {
            postSystemNotification(a.title, a.subtitle)
        }
    }
    func dismissAlert() { alertInfo = nil; mode = .collapsed }
    func snooze() {
        if let f = alertInfo, f.snooze {
            let d = Date().addingTimeInterval(300)
            reminders.append(Reminder(title: f.title, kind: .once, time: d, date: d))
        }
        dismissAlert()
    }

    func toggleMute() {
        return
    }

    // MARK: tasks
    func updateTodo(_ id: UUID, _ change: (inout TodoItem) -> Void) {
        guard let i = todos.firstIndex(where: { $0.id == id }) else { return }
        change(&todos[i])
    }

    // MARK: reminders
    private func fire(_ r: Reminder) {
        if let i = reminders.firstIndex(where: { $0.id == r.id }) {
            if r.kind == .once { reminders[i].active = false }
            else { reminders[i].date = r.nextOccurrence() ?? r.date }
        }
        notify(AlertInfo(title: r.title,
                         subtitle: "Reminder · " + r.time.formatted(date: .omitted, time: .shortened),
                         snooze: true, speak: r.sound))
    }
    func toggleReminder(_ id: UUID) {
        guard let i = reminders.firstIndex(where: { $0.id == id }) else { return }
        reminders[i].active.toggle()
        if reminders[i].active, reminders[i].date <= Date() {
            reminders[i].date = reminders[i].nextOccurrence() ?? reminders[i].date
        }
    }
    func upsertReminder(_ r: Reminder) {
        if let i = reminders.firstIndex(where: { $0.id == r.id }) { reminders[i] = r } else { reminders.append(r) }
    }

    // MARK: focus
    func resetFocus() {
        focusRunning = false
        phase = .work
        focusLeft = workMin * 60
        sessions = 0
    }

    /// Starts a phase from the timer chips.
    func startFocusPhase(_ p: FocusPhase) {
        phase = p
        focusLeft = (p == .work ? workMin : p == .shortBreak ? breakMin : longBreakMin) * 60
        focusRunning = true
    }

    /// Ends the current phase early. A skipped focus session does not count.
    func skipPhase() {
        guard phase != .work || focusRunning || focusLeft < focusTotal else { return }
        advancePhase(completed: false)
    }

    private func finishPhase() {
        advancePhase(completed: true)
    }

    private func advancePhase(completed: Bool) {
        let finished = phase
        switch finished {
        case .work:
            if completed {
                sessions += 1
                focusSessionsToday += 1
                focusSecondsToday += workMin * 60
                let every = max(sessionsBeforeLong, 1)
                phase = (completed && sessions % every == 0) ? .longBreak : .shortBreak
            } else {
                phase = .shortBreak
            }
            focusLeft = (phase == .longBreak ? longBreakMin : breakMin) * 60
            if completed {
                let long = phase == .longBreak
                notify(AlertInfo(title: long ? "Long break" : "Focus complete",
                                 subtitle: long ? "\(longBreakMin) min · you earned it" : "Break time · \(breakMin) min",
                                 icon: long ? "figure.walk" : "cup.and.saucer.fill",
                                 tint: IslandTab.focus.tint,
                                 sticky: false, until: Date().addingTimeInterval(6)))
            }
            focusRunning = autoStartBreaks
        case .shortBreak, .longBreak:
            phase = .work
            focusLeft = workMin * 60
            if completed {
                notify(AlertInfo(title: "Break over", subtitle: "Back to focus · \(workMin) min",
                                 icon: "bolt.fill", tint: IslandTab.tasks.tint,
                                 sticky: false, until: Date().addingTimeInterval(6)))
            }
            focusRunning = autoStartFocus
        }
    }

    private func resetDailyFocusStatsIfNeeded() {
        let today = Store.dayKey
        guard focusStatsDay != today else { return }
        focusStatsDay = today
        UserDefaults.standard.set(today, forKey: "focusStatsDay")
        focusSessionsToday = 0
        focusSecondsToday = 0
    }
    private func setAwake() {
        if keepAwake {
            awake = ProcessInfo.processInfo.beginActivity(
                options: [.idleSystemSleepDisabled, .idleDisplaySleepDisabled], reason: "Inertia keep awake")
        } else if let a = awake {
            ProcessInfo.processInfo.endActivity(a); awake = nil
        }
    }

    // MARK: calendar reminders
    private func checkCalendarReminders() {
        guard calendarAlerts, mode != .alert else { return }
        for event in CalendarEngine.shared.eventsStarting(within: 5 * 60) where !notifiedEventIDs.contains(event.id) {
            notifiedEventIDs.insert(event.id)
            let subtitle = event.joinURL != nil ? "Starts soon · Join when ready" : "Starts \(event.start.formatted(date: .omitted, time: .shortened))"
            notify(AlertInfo(title: event.title,
                             subtitle: subtitle,
                             icon: "calendar",
                             tint: IslandTab.calendar.tint,
                             snooze: false,
                             sticky: true,
                             until: Date().addingTimeInterval(20),
                             speak: false,
                             joinURL: event.joinURL))
        }
    }

    // MARK: app launching
    func launch(_ bundleID: String) {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    // MARK: launcher
    func pinLauncher(_ tool: LauncherTool) {
        guard !launcherPins.contains(tool) else { return }
        launcherPins.append(tool)
    }

    func unpinLauncher(_ tool: LauncherTool) {
        launcherPins.removeAll { $0 == tool }
    }

    // MARK: system notifications (optional backup alert)
    func refreshNotifStatus() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        UNUserNotificationCenter.current().getNotificationSettings { s in
            let ok = s.authorizationStatus == .authorized || s.authorizationStatus == .provisional
            DispatchQueue.main.async { self.notifAuthorized = ok }
        }
    }
    func requestNotifications() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            DispatchQueue.main.async {
                self.notifAuthorized = granted
                if !granted { self.systemNotifications = false }
            }
        }
    }
    func postSystemNotification(_ title: String, _ body: String) {
        guard systemNotifications, notifAuthorized, Bundle.main.bundleIdentifier != nil else { return }
        let c = UNMutableNotificationContent()
        c.title = title; c.body = body
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: c, trigger: nil))
    }

    // MARK: erase all data
    /// Wipes every UserDefaults key written by this app plus the NSURLCache (artwork images).
    /// Called from Settings ▸ About. Safe to call at any time — the app stays running.
    func eraseAllData() {
        // 1. UserDefaults — remove every key we own
        let ud = UserDefaults.standard
        let ownedKeys = [
            "todos2", "notes", "reminders2", "localCalendarEvents",
            "workMin", "breakMin", "longBreakMin", "sessionsBeforeLong",
            "autoStartBreaks", "autoStartFocus",
            "focusSessionsToday", "focusSecondsToday", "focusStatsDay",
            "showMusicInNotch", "trackPeek", "animSpeed", "showLyrics",
            "showPrivacyIndicators", "clipboardEnabled",
            "showNetworkInNotch",
            "batteryAlerts", "networkAlerts", "calendarAlerts",
            "alertSounds", "speakReminders", "sysNotif", "clipboardHistory",
            "launchAtLogin",
            "displayTarget", "islandWidth", "openPanelWidth", "launcherPins",
            "lowBatteryThreshold", "musicPreviewDuration",
            "enableSpotifyAppleScriptControl", "enableAppleMusicAppleScriptControl",
            "enableLockSound", "hideNotchWhenFullscreen", "showFocusAnimations",
            "focusAnimationDuration", "hideFocusLabel", "showSoundStatus",
            "soundDisplayStyle", "soundLineWidth",
            "showBrightnessStatus", "brightnessDisplayStyle", "brightnessLineWidth",
            "showNotchEmoji", "leftEmojiUseLottie", "notchEmoji", "showRightNotchEmoji", "rightNotchEmoji",
            "emojiOnlyWhenIdle", "notchEmojiSize",
            "hudDuration", "hudExpansion", "hudQueueEnabled",
            "showBatteryInNotch", "showBrightnessStatus", "brightnessDisplayStyle", "brightnessLineWidth",
            "enableCodexApprovalAlertSound",
            "enableCodexCompletedAlertSound", "codexCompletedAlertDuration",
            "lastPresentedWhatsNewVersion"
        ]
        ownedKeys.forEach { ud.removeObject(forKey: $0) }
        ud.synchronize()

        // 2. Caches: artwork thumbnails, lyrics and clipboard image files
        URLCache.shared.removeAllCachedResponses()
        let fm = FileManager.default
        if let caches = fm.urls(for: .cachesDirectory, in: .userDomainMask).first {
            try? fm.removeItem(at: caches.appendingPathComponent("Inertia/lyrics"))
        }
        ClipboardManager.shared.eraseAll()
        CalendarEngine.shared.eraseLocalEvents()

        // 3. Reset in-memory published state to defaults
        todos = []
        notes = []
        reminders = []
        alertInfo = nil
        phase = .work
        workMin = 25; breakMin = 5; longBreakMin = 15; sessionsBeforeLong = 4
        autoStartBreaks = true; autoStartFocus = false
        focusLeft = 25 * 60; focusRunning = false; sessions = 0
        focusSessionsToday = 0; focusSecondsToday = 0
        showMusicInNotch = true; trackPeek = true; animSpeed = 1.0; showLyrics = true
        showPrivacyIndicators = true; clipboardEnabled = true
        showNetworkInNotch = true
        batteryAlerts = true; networkAlerts = true; calendarAlerts = true
        showBatteryInNotch = false
        alertSounds = true; speakReminders = true; systemNotifications = false
        launcherPins = LauncherTool.defaultPins
        showMenu = false
        featureSettings.resetGeneral()
        featureSettings.resetFocus()
        featureSettings.resetSound()
        featureSettings.resetBrightness()
        featureSettings.resetBattery()
        featureSettings.resetMusic()
        mode = .collapsed
        lyrics = LyricsResult()
        notifiedEventIDs.removeAll()
    }
}

extension Store {
    func toggleCommandPalette() {
    }

    // MARK: - TASK 2: Intro animation

    /// Start the intro. Does nothing if islandHidden or (introEnabled false and not forced),
    /// or if the screen is locked, or if fullscreen-hide is active.
    func startIntro(force: Bool = false) {
        guard !islandHidden else { return }
        guard !isScreenLocked else { return }
        guard featureSettings.introEnabled || force else { return }
        guard !introActive else { return }
        withAnimation(.inertiaLiquid(speed: animSpeed, reduceMotion: false)) {
            introActive = true
        }
    }

    func finishIntro() {
        guard introActive else { return }
        withAnimation(.inertiaLiquid(speed: animSpeed, reduceMotion: false)) {
            introActive = false
        }
    }
}

extension Store {
    func toggleMicMute() {
        // Best effort mic mute via system - placeholder for full implementation
    }
}
