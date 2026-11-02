import SwiftUI
import AppKit
import CoreAudio
import ApplicationServices

// MARK: - Types
enum PermState: Equatable { case granted, denied, notDetermined, notRunning, unknown }

struct MediaApp: Identifiable {
    enum Kind { case player, chromium, safari }
    let name: String
    let bundle: String
    let kind: Kind
    var id: String { bundle }
    var installed: Bool { NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundle) != nil }
}

struct TabRef { var app: MediaApp; var win: Int; var tab: Int }
struct MediaResult { var np = NowPlaying(); var tab: TabRef? = nil; var js: [String: Bool] = [:] }

// MARK: - Engine
extension Store {
    static let sep = "§§"

    static let mediaApps: [MediaApp] = [
        MediaApp(name: "Music", bundle: "com.apple.Music", kind: .player),
        MediaApp(name: "Spotify", bundle: "com.spotify.client", kind: .player),
        MediaApp(name: "Google Chrome", bundle: "com.google.Chrome", kind: .chromium),
        MediaApp(name: "Brave Browser", bundle: "com.brave.Browser", kind: .chromium),
        MediaApp(name: "Microsoft Edge", bundle: "com.microsoft.edgemac", kind: .chromium),
        MediaApp(name: "Arc", bundle: "company.thebrowser.Browser", kind: .chromium),
        MediaApp(name: "Safari", bundle: "com.apple.Safari", kind: .safari)
    ]

    static let sites: [(String, String)] = [
        ("music.youtube.com", "YouTube Music"), ("youtube.com/watch", "YouTube"), ("open.spotify.com", "Spotify Web"),
        ("soundcloud.com", "SoundCloud"), ("netflix.com/watch", "Netflix"), ("primevideo.com", "Prime Video"),
        ("hotstar.com", "Hotstar"), ("jiosaavn.com", "JioSaavn"), ("gaana.com", "Gaana"),
        ("twitch.tv", "Twitch"), ("vimeo.com", "Vimeo")
    ]

    // MARK: refresh
    func refreshMusic() {
        if mediaBusy {
            NSLog("INERTIA music poll skipped: busy")
            return
        }
        mediaBusy = true
        let running = Set(NSWorkspace.shared.runningApplications.compactMap { $0.bundleIdentifier })
        let allowed = Set(perms.filter { $0.value == .granted }.map { $0.key })
        NSLog("INERTIA music poll start: running=\(running.count) allowed=\(allowed.count)")
        scriptQ.async { [weak self] in
            guard let self = self else { return }
            let r = self.detectMedia(running: running, allowed: allowed)
            DispatchQueue.main.async { self.applyMedia(r); self.mediaBusy = false }
        }
    }

    private func applyMedia(_ r: MediaResult) {
        NSLog("INERTIA music apply: app=\(r.np.app ?? "nil") title=\(r.np.title) playing=\(r.np.playing) precise=\(r.np.precise) hold=\(Date() < holdUntil)")
        var np = r.np
        // Right after the user presses play/pause we trust their press for a moment,
        // so the button flips instantly instead of waiting for the player to catch up.
        if Date() < holdUntil { np.playing = holdValue }
        // Detection hysteresis: keep "playing" latched for a grace period so a
        // single unreliable poll (browser tabs without Precise JS, transient
        // AppleScript errors, audio-device flag lag) doesn't collapse the music
        // notch prematurely after the track-change peek expires.
        if np.app != nil, !np.playing, playing.playing,
           Date().timeIntervalSince(lastPlayingAt) < Store.mediaGracePeriod {
            np.playing = true
        }
        if np.playing { lastPlayingAt = Date() }
        mediaTab = r.tab
        for (k, v) in r.js where jsReady[k] != v { jsReady[k] = v }
        if np != playing { playing = np }

        let key = np.app == nil ? "" : "\(np.bundleID ?? "")|\(np.title)"
        if key != lastTrackKey {
            lastTrackKey = key
            if !key.isEmpty, np.playing, showMusicInNotch, trackPeek, mode == .collapsed {
                peek = true
                peekUntil = Date().addingTimeInterval(max(1, Store.shared.featureSettings.musicPreviewDuration))
            }
            // Fetch lyrics for new track
            if !key.isEmpty { fetchLyrics(for: np) } else { lyrics = LyricsResult() }
        }
    }

    // MARK: detection (runs on scriptQ)
    private func detectMedia(running: Set<String>, allowed: Set<String>) -> MediaResult {
        var cands: [MediaResult] = []
        var jsState: [String: Bool] = [:]

        for app in Store.mediaApps where app.kind == .player && running.contains(app.bundle) && allowed.contains(app.bundle) {
            if let np = nativeState(app) { cands.append(MediaResult(np: np)) }
        }

        let audio = Store.audioActive()
        for app in Store.mediaApps where app.kind != .player && running.contains(app.bundle) && allowed.contains(app.bundle) {
            let (list, js) = browserTabs(app)
            if let js = js { jsState[app.bundle] = js }
            for var c in list {
                if !c.np.precise { c.np.playing = audio }   // no JS access: best guess from audio output
                cands.append(c)
            }
        }

        var pick = cands.first(where: { $0.np.playing }) ?? cands.first(where: { $0.np.native }) ?? cands.first
        if pick == nil && audio {
            var np = NowPlaying()
            np.app = "System audio"; np.playing = true; np.title = "Audio is playing"; np.source = "System"
            pick = MediaResult(np: np)
        }
        NSLog("INERTIA music detect: audio=\(audio) candidates=\(cands.count) pick=\(pick?.np.app ?? "nil") pickPlaying=\(pick?.np.playing ?? false)")
        if pick == nil { NSLog("INERTIA music poll returned empty") }
        var result = pick ?? MediaResult()
        result.js = jsState
        return result
    }

    private func nativeState(_ app: MediaApp) -> NowPlaying? {
        let src: String
        if app.name == "Spotify" {
            src = """
            tell application "Spotify"
                try
                    if player state is stopped then return "stopped"
                    set t to current track
                    return (player state as text) & "§§" & (name of t) & "§§" & (artist of t) & "§§" & ((player position as integer) as text) & "§§" & ((((duration of t) / 1000) as integer) as text) & "§§" & (artwork url of t)
                on error
                    return "stopped"
                end try
            end tell
            """
        } else {
            src = """
            tell application "Music"
                try
                    if player state is stopped then return "stopped"
                    set t to current track
                    return (player state as text) & "§§" & (name of t) & "§§" & (artist of t) & "§§" & ((player position as integer) as text) & "§§" & ((duration of t as integer) as text) & "§§"
                on error
                    return "stopped"
                end try
            end tell
            """
        }
        guard let out = run(src) else {
            NSLog("INERTIA music native \(app.name): AppleScript returned nil")
            return nil
        }
        let p = out.components(separatedBy: Store.sep)
        guard p.count >= 5 else {
            NSLog("INERTIA music native \(app.name): incomplete state \(out)")
            return nil
        }
        var np = NowPlaying()
        np.app = app.name; np.bundleID = app.bundle; np.native = true; np.precise = true
        np.playing = p[0].lowercased().contains("play")
        np.title = p[1]; np.artist = p[2]; np.source = app.name
        np.position = Double(p[3].replacingOccurrences(of: ",", with: ".")) ?? 0
        np.duration = Double(p[4].replacingOccurrences(of: ",", with: ".")) ?? 0
        if p.count > 5, !p[5].isEmpty, let u = URL(string: p[5]) { np.artwork = u }
        return np
    }

    private func browserTabs(_ app: MediaApp) -> ([MediaResult], Bool?) {
        let list: String
        if app.kind == .safari {
            list = """
            tell application "Safari"
                set out to ""
                set wi to 0
                repeat with w in windows
                    set wi to wi + 1
                    set i to 0
                    repeat with t in tabs of w
                        set i to i + 1
                        try
                            set out to out & wi & "§§" & i & "§§" & ((t is current tab of w) as text) & "§§" & (URL of t) & "§§" & (name of t) & linefeed
                        end try
                    end repeat
                end repeat
                return out
            end tell
            """
        } else {
            list = """
            tell application "\(app.name)"
                set out to ""
                set wi to 0
                repeat with w in windows
                    set wi to wi + 1
                    set a to active tab index of w
                    set i to 0
                    repeat with t in tabs of w
                        set i to i + 1
                        try
                            set out to out & wi & "§§" & i & "§§" & ((a is i) as text) & "§§" & (URL of t) & "§§" & (title of t) & linefeed
                        end try
                    end repeat
                end repeat
                return out
            end tell
            """
        }
        guard let out = run(list) else {
            NSLog("INERTIA music browser \(app.name): tab enumeration returned nil")
            return ([], nil)
        }

        struct Tab { var win: Int; var tab: Int; var active: Bool; var title: String; var site: String }
        var tabs: [Tab] = []
        for line in out.components(separatedBy: "\n") {
            let f = line.components(separatedBy: Store.sep)
            guard f.count >= 5, let wi = Int(f[0]), let ti = Int(f[1]) else { continue }
            guard let site = Store.sites.first(where: { f[3].contains($0.0) })?.1 else { continue }
            tabs.append(Tab(win: wi, tab: ti, active: f[2] == "true", title: f[4], site: site))
        }
        let ordered = tabs.filter { $0.active } + tabs.filter { !$0.active }

        var jsWorked: Bool? = nil
        var results: [MediaResult] = []
        for t in ordered.prefix(5) {
            var np = NowPlaying()
            np.app = app.name; np.bundleID = app.bundle; np.browser = true
            np.title = Store.cleanTitle(t.title); np.source = t.site

            if jsWorked != false, let raw = pageExec(app, t.win, t.tab, Store.stateJS) {
                jsWorked = true
                if raw == "none" { continue }                       // matching site, but nothing to play on this page
                let f = raw.components(separatedBy: Store.sep)
                if f.count >= 6 {
                    np.precise = true
                    np.playing = f[0] == "1"
                    if !f[1].isEmpty { np.title = f[1] }
                    np.artist = f[2]
                    if !f[3].isEmpty, let u = URL(string: f[3]) { np.artwork = u }
                    np.position = Double(f[4]) ?? 0
                    np.duration = Double(f[5]) ?? 0
                }
            } else if jsWorked == nil {
                jsWorked = false
            }
            results.append(MediaResult(np: np, tab: TabRef(app: app, win: t.win, tab: t.tab)))
        }
        NSLog("INERTIA music browser \(app.name): tabs=\(tabs.count) results=\(results.count) jsWorked=\(jsWorked.map(String.init) ?? "nil")")
        return (results, jsWorked)
    }

    private static func cleanTitle(_ raw: String) -> String {
        var title = raw
            .replacingOccurrences(of: " - YouTube Music", with: "")
            .replacingOccurrences(of: " - YouTube", with: "")
        if title.hasPrefix("("), let r = title.firstIndex(of: ")") {
            title = String(title[title.index(after: r)...]).trimmingCharacters(in: .whitespaces)
        }
        return title
    }

    // MARK: JavaScript helpers (only work when the user enables "Allow JavaScript from Apple Events")
    private static let stateJS = "(function(){var v=[].slice.call(document.querySelectorAll('video,audio'));var p=v.filter(function(e){return !e.paused&&!e.ended&&e.readyState>2});var e=p[0]||v.filter(function(e){return e.duration>0})[0];if(!e){return 'none'}var m=navigator.mediaSession&&navigator.mediaSession.metadata;var a='';if(m&&m.artwork&&m.artwork.length){a=m.artwork[m.artwork.length-1].src}return [p.length>0?'1':'0',m?m.title:'',m?m.artist:'',a,Math.floor(e.currentTime||0),Math.floor(isFinite(e.duration)?e.duration:0)].join('§§')})()"

    private static let toggleJS = "(function(){var v=[].slice.call(document.querySelectorAll('video,audio'));var p=v.filter(function(e){return !e.paused});if(p.length){p.forEach(function(e){e.pause()});return 'paused'}var e=v.filter(function(e){return e.duration>0})[0];if(e){e.play();return 'playing'}return 'none'})()"

    private static func clickJS(_ selectors: [String]) -> String {
        let list = selectors.map { "\"" + $0 + "\"" }.joined(separator: ",")
        return "(function(){var s=[\(list)];for(var i=0;i<s.length;i++){var b=document.querySelector(s[i]);if(b){b.click();return 'ok'}}return 'none'})()"
    }

    private static let nextSelectors = [".next-button", ".ytp-next-button", "[data-testid='control-button-skip-forward']", ".skipControl__next"]
    private static let prevSelectors = [".previous-button", ".ytp-prev-button", "[data-testid='control-button-skip-back']", ".skipControl__previous"]

    private static func esc(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }

    private func pageExec(_ app: MediaApp, _ w: Int, _ t: Int, _ js: String) -> String? {
        let code = Store.esc(js)
        let src: String
        if app.kind == .safari {
            src = "tell application \"Safari\" to do JavaScript \"\(code)\" in tab \(t) of window \(w)"
        } else {
            src = "tell application \"\(app.name)\" to execute (tab \(t) of window \(w)) javascript \"\(code)\""
        }
        return run(src)
    }

    fileprivate func run(_ src: String) -> String? {
        let wrapped = "with timeout of 3 seconds\n\(src)\nend timeout"
        guard let script = NSAppleScript(source: wrapped) else { return nil }
        var err: NSDictionary?
        let r = script.executeAndReturnError(&err)
        if err != nil { return nil }
        return r.stringValue
    }

    // MARK: controls
    func music(_ cmd: String) {
        let cur = playing
        if cmd == "playpause" {
            // Optimistic flip so the button reacts at once.
            var p = playing
            p.playing.toggle()
            playing = p
            holdValue = p.playing
            holdUntil = Date().addingTimeInterval(cur.precise ? 1.0 : 2.8)
            // When the user pauses, reset the detection-hysteresis timestamp so
            // the hysteresis in applyMedia does NOT keep "playing" latched.
            if !p.playing { lastPlayingAt = Date.distantPast }
        }
        let ref = mediaTab
        scriptQ.async { [weak self] in
            guard let self = self else { return }
            var handled = false
            if cur.native, let app = cur.app {
                let result = self.run("tell application \"\(app)\" to \(cmd)")
                if result != nil {
                    handled = true
                } else {
                    // AppleScript returned nil — almost always means automation was denied.
                    let bundle = cur.bundleID ?? ""
                    let st = Store.automationState(bundle, ask: false)
                    DispatchQueue.main.async {
                        switch st {
                        case .denied:
                            self.mediaHint = "\(app) automation is blocked. Go to Settings → Permissions and press Allow."
                        case .notDetermined:
                            self.mediaHint = "\(app) needs your permission. Go to Settings → Permissions and press Allow."
                        case .notRunning:
                            self.mediaHint = "\(app) is not running."
                        default:
                            self.mediaHint = "Could not control \(app). Try re-granting automation in Settings → Permissions."
                        }
                    }
                }
            } else if let ref = ref {
                let js: String
                switch cmd {
                case "playpause": js = Store.toggleJS
                case "next track": js = Store.clickJS(Store.nextSelectors)
                default: js = Store.clickJS(Store.prevSelectors)
                }
                if let r = self.pageExec(ref.app, ref.win, ref.tab, js), r != "none" { handled = true }
            }
            if !handled {
                DispatchQueue.main.async {
                    // Only try media keys if we have accessibility; otherwise surface a clear hint.
                    if AXIsProcessTrusted() {
                        self.pressMediaKey(cmd == "playpause" ? 16 : (cmd == "next track" ? 17 : 18))
                    } else {
                        self.mediaHint = cur.browser
                            ? "Enable Precise mode in Settings ▸ Music so Inertia can control this browser tab."
                            : "Accessibility access needed for media keys. Open Settings ▸ Permissions."
                    }
                }
            } else {
                DispatchQueue.main.async { self.mediaHint = nil }
            }
        }
        let delay = cur.precise ? 0.9 : 2.9
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { self.refreshMusic() }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { self.refreshMusic() }
    }

    /// Seek to a specific position (seconds). Works for native players and browser tabs with Precise mode.
    func seek(to position: Double) {
        let cur = playing
        // Optimistic local update so the scrubber moves immediately.
        var p = playing; p.position = position; playing = p
        holdUntil = Date().addingTimeInterval(cur.precise ? 1.5 : 3.0)

        let ref = mediaTab
        scriptQ.async { [weak self] in
            guard let self = self else { return }
            if cur.native, let app = cur.app {
                if app == "Spotify" {
                    _ = self.run("tell application \"Spotify\" to set player position to \(position)")
                } else {
                    _ = self.run("tell application \"Music\" to set player position to \(position)")
                }
            } else if let ref = ref {
                let js = "(function(){var v=document.querySelector('video,audio');if(v){v.currentTime=\(position);return 'ok'}return 'none'})()"
                _ = self.pageExec(ref.app, ref.win, ref.tab, js)
            }
            DispatchQueue.main.async { self.refreshMusic() }
        }
    }

    private func pressMediaKey(_ key: Int) {
        if !AXIsProcessTrusted() {
            mediaHint = "Media keys need Accessibility access. Open Settings ▸ Permissions."
            return
        }
        mediaHint = nil
        for down in [true, false] {
            let flags = NSEvent.ModifierFlags(rawValue: down ? 0xA00 : 0xB00)
            let data1 = (key << 16) | ((down ? 0xA : 0xB) << 8)
            NSEvent.otherEvent(with: .systemDefined, location: .zero, modifierFlags: flags, timestamp: 0,
                               windowNumber: 0, context: nil, subtype: 8, data1: data1, data2: -1)?
                .cgEvent?.post(tap: .cghidEventTap)
        }
    }

    static func audioActive() -> Bool {
        var dev = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                              mScope: kAudioObjectPropertyScopeGlobal,
                                              mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &dev) == noErr else { return false }
        var running: UInt32 = 0
        size = UInt32(MemoryLayout<UInt32>.size)
        addr = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
                                          mScope: kAudioObjectPropertyScopeGlobal,
                                          mElement: kAudioObjectPropertyElementMain)
        AudioObjectGetPropertyData(dev, &addr, 0, nil, &size, &running)
        return running != 0
    }

    // MARK: permissions
    static func automationState(_ bundle: String, ask: Bool) -> PermState {
        guard !NSRunningApplication.runningApplications(withBundleIdentifier: bundle).isEmpty else { return .notRunning }
        let target = NSAppleEventDescriptor(bundleIdentifier: bundle)
        let status = AEDeterminePermissionToAutomateTarget(target.aeDesc, typeWildCard, typeWildCard, ask)
        NSLog("INERTIA AE \(bundle) ask=\(ask) status=\(status)")
        switch Int(status) {
        case 0: return .granted
        case -1743: return .denied            // errAEEventNotPermitted
        case -1744: return .notDetermined     // errAEEventWouldRequireUserConsent
        default: return .unknown
        }
    }

    func refreshPermissions() {
        // AXIsProcessTrusted() always re-checks TCC; no options dictionary needed here.
        axTrusted = AXIsProcessTrusted()
        let apps = Store.mediaApps.filter { $0.installed }
        let old = perms
        DispatchQueue.global(qos: .utility).async { [weak self] in
            var out: [String: PermState] = [:]
            for a in apps {
                var st = Store.automationState(a.bundle, ask: false)
                // A closed app can't be asked, so remember what we already knew.
                if st == .notRunning, let o = old[a.bundle], o == .granted || o == .denied { st = o }
                out[a.bundle] = st
            }
            DispatchQueue.main.async {
                guard let self = self else { return }
                if self.perms != out { self.perms = out }
            }
        }
        refreshNotifStatus()
    }

    /// Shows the macOS "Inertia wants to control <app>" prompt. The app has to be running for macOS to ask.
    func requestAutomation(_ bundle: String, retry: Bool = true) {
        if NSRunningApplication.runningApplications(withBundleIdentifier: bundle).isEmpty {
            launch(bundle)
            if retry {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { self.requestAutomation(bundle, retry: false) }
            }
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            _ = Store.automationState(bundle, ask: true)     // blocks until the user answers
            if let name = Store.mediaApps.first(where: { $0.bundle == bundle })?.name {
                _ = self.run("tell application \"\(name)\" to get name")
            }
            DispatchQueue.main.async { self.refreshPermissions() }
        }
    }

    func requestAccessibility() {
        // Use the raw string literal — kAXTrustedCheckOptionPrompt is an Unmanaged<CFString>
        // that can't be cast to String, but the literal value bridges fine as a CFDictionary key.
        let opts = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        axTrusted = AXIsProcessTrustedWithOptions(opts)
        // Poll a few times after the user (presumably) grants access in System Settings.
        for delay in [2.0, 4.0, 8.0, 15.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self, !self.axTrusted else { return }
                self.axTrusted = AXIsProcessTrusted()
            }
        }
    }

    func openPrivacy(_ pane: String) {
        if let u = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(u)
        }
    }
    func openNotificationSettings() {
        if let u = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
            NSWorkspace.shared.open(u)
        }
    }
}
