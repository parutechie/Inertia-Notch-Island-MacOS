import AppKit
import AVFAudio
import CoreGraphics
import Foundation

func isScreenLocked() -> Bool {
    guard let dictionary = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
    return (dictionary["CGSSessionScreenIsLocked"] as? NSNumber)?.boolValue ?? false
}

@MainActor
final class UnlockSoundPlayer {
    static let shared = UnlockSoundPlayer()

    private var player: AVAudioPlayer?
    private var lastPlayDate: Date?

    private init() {
        let url = ["aiff", "wav", "mp3"].lazy.compactMap {
            Bundle.main.url(forResource: "Unlock", withExtension: $0)
        }.first
        guard let url else { return }
        player = try? AVAudioPlayer(contentsOf: url)
        player?.volume = 0.15
        player?.prepareToPlay()
    }

    func play(bypassThrottle: Bool = false) {
        guard let player else { return }
        let now = Date()
        if !bypassThrottle, let lastPlayDate, now.timeIntervalSince(lastPlayDate) < 0.5 { return }
        if player.isPlaying {
            guard bypassThrottle else { return }
            player.stop()
        }
        lastPlayDate = now
        player.currentTime = 0
        player.volume = 0.15
        player.prepareToPlay()
        player.play()
    }
}

@MainActor
final class LockScreenMonitor {
    static let shared = LockScreenMonitor()

    private var started = false
    private var observers: [NSObjectProtocol] = []
    private var locked = false

    private init() {}

    func start() {
        guard !started else { return }
        started = true
        locked = isScreenLocked()
        Store.shared.isScreenLocked = locked

        let center = DistributedNotificationCenter.default()
        observers.append(center.addObserver(forName: NSNotification.Name("com.apple.screenIsLocked"),
                                            object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.handle(locked: true) }
        })
        observers.append(center.addObserver(forName: NSNotification.Name("com.apple.screenIsUnlocked"),
                                            object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.handle(locked: false) }
        })
    }

    private func handle(locked: Bool) {
        let wasLocked = self.locked
        self.locked = locked
        Store.shared.isScreenLocked = locked
        if wasLocked, !locked, Store.shared.featureSettings.enableLockSound {
            UnlockSoundPlayer.shared.play()
        }
    }
}
