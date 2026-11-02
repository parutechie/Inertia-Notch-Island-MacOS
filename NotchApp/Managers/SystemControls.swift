import AppKit
import CoreAudio

extension Notification.Name {
    static let inertiaManualVolumeInput = Notification.Name("app.inertia.manual-volume-input")
    static let inertiaManualBrightnessInput = Notification.Name("app.inertia.manual-brightness-input")
}

@MainActor
final class ManualSystemControlMonitor {
    static let shared = ManualSystemControlMonitor()

    private(set) var volumeInputGeneration = 0
    private(set) var brightnessInputGeneration = 0
    private var lastVolumeInputDate = Date.distantPast
    private var lastBrightnessInputDate = Date.distantPast
    private var globalMonitor: Any?
    private var localMonitor: Any?

    private init() {}

    func start() {
        guard globalMonitor == nil, localMonitor == nil else { return }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .systemDefined) { [weak self] event in
            Task { @MainActor in self?.handle(event) }
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .systemDefined) { [weak self] event in
            self?.handle(event)
            return event
        }
    }

    func recentVolumeInput(after generation: Int, maximumAge: TimeInterval = 1.2) -> Int? {
        guard volumeInputGeneration > generation,
              Date().timeIntervalSince(lastVolumeInputDate) <= maximumAge else { return nil }
        return volumeInputGeneration
    }

    func recentBrightnessInput(after generation: Int, maximumAge: TimeInterval = 1.2) -> Int? {
        guard brightnessInputGeneration > generation,
              Date().timeIntervalSince(lastBrightnessInputDate) <= maximumAge else { return nil }
        return brightnessInputGeneration
    }

    private func handle(_ event: NSEvent) {
        guard event.subtype.rawValue == 8 else { return }

        let data = UInt32(truncatingIfNeeded: event.data1)
        let keyCode = Int((data & 0xFFFF0000) >> 16)
        let keyState = Int((data & 0x0000FF00) >> 8)
        guard keyState == 0x0A else { return }

        switch keyCode {
        case 0, 1, 7:
            volumeInputGeneration += 1
            lastVolumeInputDate = Date()
            NotificationCenter.default.post(name: .inertiaManualVolumeInput, object: nil)
        case 2, 3:
            brightnessInputGeneration += 1
            lastBrightnessInputDate = Date()
            NotificationCenter.default.post(name: .inertiaManualBrightnessInput, object: nil)
        default:
            break
        }
    }
}

@MainActor
final class SystemControlCenter {
    static let shared = SystemControlCenter()

    private var started = false
    private var volumeObserver: NSObjectProtocol?
    private var brightnessObserver: NSObjectProtocol?
    private var volumeTimer: Timer?
    private var refreshTask: Task<Void, Never>?
    private var brightnessTask: Task<Void, Never>?
    private var lastVolume: Double?
    private var lastMuted = false
    private var handledVolumeGeneration = 0
    private var handledBrightnessGeneration = 0

    private init() {}

    func start() {
        guard !started else { return }
        started = true
        ManualSystemControlMonitor.shared.start()
        BrightnessManager.shared.start()

        lastVolume = SystemOutputVolume.currentVolume()
        lastMuted = SystemOutputVolume.isMuted() ?? false

        volumeObserver = NotificationCenter.default.addObserver(
            forName: .inertiaManualVolumeInput, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handleManualVolume() }
        }

        brightnessObserver = NotificationCenter.default.addObserver(
            forName: .inertiaManualBrightnessInput, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handleManualBrightness() }
        }

        let timer = Timer(timeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.pollVolume() }
        }
        timer.tolerance = 0.75
        RunLoop.main.add(timer, forMode: .common)
        volumeTimer = timer
    }

    private func handleManualVolume() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(40))
            guard !Task.isCancelled, let self else { return }
            self.publishVolumeIfNeeded()
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            self.publishVolumeIfNeeded()
            self.refreshTask = nil
        }
    }

    private func handleManualBrightness() {
        brightnessTask?.cancel()
        brightnessTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(40))
            guard !Task.isCancelled, let self else { return }
            self.publishBrightnessIfNeeded()
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            self.publishBrightnessIfNeeded()
            self.brightnessTask = nil
        }
    }

    private func publishBrightnessIfNeeded() {
        let level = BrightnessManager.shared.brightnessLevel
        guard Store.shared.featureSettings.showBrightnessStatus else { return }
        guard let generation = ManualSystemControlMonitor.shared.recentBrightnessInput(after: handledBrightnessGeneration) else { return }
        handledBrightnessGeneration = generation
        Store.shared.showLiveStatus(.brightness(level))
    }

    private func pollVolume() {
        guard let next = SystemOutputVolume.currentVolume() else { return }
        let muted = SystemOutputVolume.isMuted() ?? false
        lastVolume = next
        lastMuted = muted
    }

    private func publishVolumeIfNeeded() {
        guard let next = SystemOutputVolume.currentVolume() else { return }
        let muted = SystemOutputVolume.isMuted() ?? lastMuted
        let previousDisplay = lastMuted ? 0 : (lastVolume ?? 0)
        let nextDisplay = muted || next <= 0.01 ? 0 : next
        let changed = abs(nextDisplay - previousDisplay) >= 0.01 || muted != lastMuted
        lastVolume = next
        lastMuted = muted

        guard changed,
              let generation = ManualSystemControlMonitor.shared.recentVolumeInput(after: handledVolumeGeneration) else { return }
        handledVolumeGeneration = generation
        guard Store.shared.featureSettings.showSoundStatus else { return }
        Store.shared.showLiveStatus(.volume(next, muted: muted || next <= 0.01))
    }
}

enum SystemOutputVolume {
    private static let scope = AudioObjectPropertyScope(kAudioDevicePropertyScopeOutput)
    private static let mainElement = AudioObjectPropertyElement(kAudioObjectPropertyElementMain)
    private static let leftElement = AudioObjectPropertyElement(1)
    private static let rightElement = AudioObjectPropertyElement(2)
    private static var cachedDevice: AudioDeviceID?
    private static var cachedAt: TimeInterval = 0

    static func currentVolume() -> Double? {
        guard let device = defaultOutputDevice() else { return nil }
        if let value = scalarValue(device: device, selector: kAudioDevicePropertyVolumeScalar, element: mainElement) {
            return Double(value)
        }
        let channels = [leftElement, rightElement].compactMap {
            scalarValue(device: device, selector: kAudioDevicePropertyVolumeScalar, element: $0)
        }
        guard !channels.isEmpty else { return nil }
        return Double(channels.reduce(Float32(0), +) / Float32(channels.count))
    }

    static func isMuted() -> Bool? {
        guard let device = defaultOutputDevice() else { return nil }
        if let value = integerValue(device: device, selector: kAudioDevicePropertyMute, element: mainElement) {
            return value != 0
        }
        let channels = [leftElement, rightElement].compactMap {
            integerValue(device: device, selector: kAudioDevicePropertyMute, element: $0)
        }
        guard !channels.isEmpty else { return nil }
        return channels.allSatisfy { $0 != 0 }
    }
    
    static func setVolume(_ volume: Double) {
        let vol = Float(min(max(volume, 0), 1))
        guard let device = defaultOutputDevice() else { return }
        var address = propertyAddress(selector: kAudioDevicePropertyVolumeScalar, element: mainElement)
        if AudioObjectHasProperty(device, &address) {
            var value = vol
            let size = UInt32(MemoryLayout<Float>.size)
            AudioObjectSetPropertyData(device, &address, 0, nil, size, &value)
        }
        for element in [leftElement, rightElement] {
            var addr = propertyAddress(selector: kAudioDevicePropertyVolumeScalar, element: element)
            if AudioObjectHasProperty(device, &addr) {
                var value = vol
                let size = UInt32(MemoryLayout<Float>.size)
                AudioObjectSetPropertyData(device, &addr, 0, nil, size, &value)
            }
        }
    }
    
    static func setMuted(_ muted: Bool) {
        let value: UInt32 = muted ? 1 : 0
        guard let device = defaultOutputDevice() else { return }
        var address = propertyAddress(selector: kAudioDevicePropertyMute, element: mainElement)
        if AudioObjectHasProperty(device, &address) {
            var v = value
            let size = UInt32(MemoryLayout<UInt32>.size)
            AudioObjectSetPropertyData(device, &address, 0, nil, size, &v)
        }
        for element in [leftElement, rightElement] {
            var addr = propertyAddress(selector: kAudioDevicePropertyMute, element: element)
            if AudioObjectHasProperty(device, &addr) {
                var v = value
                let size = UInt32(MemoryLayout<UInt32>.size)
                AudioObjectSetPropertyData(device, &addr, 0, nil, size, &v)
            }
        }
    }

    private static func defaultOutputDevice() -> AudioDeviceID? {
        let now = Date.timeIntervalSinceReferenceDate
        if let cachedDevice, now - cachedAt < 5 { return cachedDevice }

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: AudioObjectPropertyScope(kAudioObjectPropertyScopeGlobal),
            mElement: mainElement
        )
        var device = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device
        )
        guard status == noErr, device != AudioDeviceID(kAudioObjectUnknown) else {
            cachedDevice = nil
            cachedAt = now
            return nil
        }
        cachedDevice = device
        cachedAt = now
        return device
    }

    private static func scalarValue(device: AudioDeviceID, selector: AudioObjectPropertySelector, element: AudioObjectPropertyElement) -> Float32? {
        var address = propertyAddress(selector: selector, element: element)
        guard AudioObjectHasProperty(device, &address) else { return nil }
        var value = Float32(0)
        var size = UInt32(MemoryLayout<Float32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr else { return nil }
        return min(max(value, 0), 1)
    }

    private static func integerValue(device: AudioDeviceID, selector: AudioObjectPropertySelector, element: AudioObjectPropertyElement) -> UInt32? {
        var address = propertyAddress(selector: selector, element: element)
        guard AudioObjectHasProperty(device, &address) else { return nil }
        var value = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr else { return nil }
        return value
    }

    private static func propertyAddress(selector: AudioObjectPropertySelector, element: AudioObjectPropertyElement) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
    }
}
