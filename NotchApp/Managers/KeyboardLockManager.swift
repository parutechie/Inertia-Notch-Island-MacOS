import Cocoa
import Combine
import SwiftUI
import ApplicationServices

/// Blocks all keyboard input system-wide using a CGEventTap while isLocked == true.
/// Never persisted; always starts unlocked. Auto-unlocks after keyboardLockMaxMinutes.
final class KeyboardLockManager: ObservableObject {
    static let shared = KeyboardLockManager()

    @Published private(set) var isLocked = false

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var autoUnlockTimer: Timer?

    private init() {
        // Unlock on sleep
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
    }

    // MARK: - Public API

    func toggle() {
        if isLocked { unlock() } else { lock() }
    }

    func lock() {
        guard !isLocked else { return }

        guard AXIsProcessTrusted() else {
            // Prompt for Accessibility permission
            let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            AXIsProcessTrustedWithOptions(opts)
            Store.shared.notify(AlertInfo(
                title: "Accessibility required",
                subtitle: "Allow in Settings → Privacy → Accessibility to lock the keyboard.",
                icon: "keyboard",
                tint: .orange,
                sticky: false,
                until: Date().addingTimeInterval(5)
            ))
            return
        }

        // Events to intercept: keyDown(10), keyUp(11), flagsChanged(12), systemDefined(14)
        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)
            | (1 << 14)   // NX_SYSDEFINED (media/brightness/volume)

        let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { proxy, type, event, refcon -> Unmanaged<CGEvent>? in
                let mgr = Unmanaged<KeyboardLockManager>.fromOpaque(refcon!).takeUnretainedValue()
                return mgr.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let tap else {
            Store.shared.notify(AlertInfo(
                title: "Could not lock keyboard",
                subtitle: "Make sure Accessibility permission is granted in System Settings.",
                icon: "keyboard",
                tint: .orange,
                sticky: false,
                until: Date().addingTimeInterval(5)
            ))
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isLocked = true

        // Auto-unlock timer
        let minutes = Double(IslandLayout.keyboardLockMaxMinutes)
        autoUnlockTimer = Timer.scheduledTimer(withTimeInterval: minutes * 60, repeats: false) { [weak self] _ in
            self?.unlock()
            Store.shared.notify(AlertInfo(
                title: "Keyboard unlocked",
                subtitle: "Auto-unlocked after \(IslandLayout.keyboardLockMaxMinutes) minutes.",
                icon: "keyboard",
                tint: .orange,
                sticky: false,
                until: Date().addingTimeInterval(4)
            ))
        }

        Store.shared.notify(AlertInfo(
            title: "Keyboard locked",
            subtitle: "Click the keyboard button again to unlock.",
            icon: "keyboard",
            tint: .orange,
            sticky: false,
            until: Date().addingTimeInterval(3)
        ))
        Store.shared.keyboardLocked = true
    }

    func unlock() {
        autoUnlockTimer?.invalidate()
        autoUnlockTimer = nil

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let src = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
            }
        }
        eventTap = nil
        runLoopSource = nil
        isLocked = false
        Store.shared.keyboardLocked = false

        Store.shared.notify(AlertInfo(
            title: "Keyboard unlocked",
            subtitle: "All keyboard input is restored.",
            icon: "keyboard",
            tint: .orange,
            sticky: false,
            until: Date().addingTimeInterval(3)
        ))
    }

    // MARK: - Private

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Re-enable if macOS disabled the tap
        if type.rawValue == 0xFFFFFFFE || type.rawValue == 0xFFFFFFFF {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        // Swallow all key events
        return nil
    }

    @objc private func handleSleep() {
        if isLocked { unlock() }
    }
}
