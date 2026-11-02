import Foundation
import AppKit
import AVFoundation
import CoreAudio
import CoreMediaIO

private final class PrivacyFrontmostTracker {
    static let shared = PrivacyFrontmostTracker()

    private(set) var lastBundleID: String?
    private(set) var lastName: String?
    private var observer: NSObjectProtocol?

    private init() {}

    func start() {
        guard observer == nil else { return }
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleIdentifier != Bundle.main.bundleIdentifier,
                  let bundleID = app.bundleIdentifier
            else { return }
            self?.lastBundleID = bundleID
            self?.lastName = app.localizedName
        }
    }
}

extension Store {
    func startPrivacyMonitor() {
        guard !privacyTimerRunning else { return }
        privacyTimerRunning = true
        PrivacyFrontmostTracker.shared.start()
        let timer = Timer(timeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.refreshPrivacy()
        }
        RunLoop.main.add(timer, forMode: .common)
        refreshPrivacy()
    }

    func refreshPrivacy() {
        let micOwner = micInputApplication()
        let fallbackMic = micOwner == nil ? fallbackMicApplication() : nil
        let mic = micOwner != nil || fallbackMic != nil
        let cam = isCameraActive()
        let screenApp = screenCaptureApplication(mic: mic, camera: cam)
        let screen = screenApp != nil
        let active = mic || cam || screen

        if active, privacySince == nil { privacySince = Date() }
        if !active { privacySince = nil }

        if micInUse != mic { micInUse = mic }
        if cameraInUse != cam { cameraInUse = cam }
        if screenSharing != screen { screenSharing = screen }

        let micApp = micOwner ?? fallbackMic
        micAppName = mic ? micApp?.localizedName : nil
        micAppBundleID = mic ? micApp?.bundleIdentifier : nil
        screenAppName = screen ? screenApp?.localizedName : nil
        screenAppBundleID = screen ? screenApp?.bundleIdentifier : nil

        if cam {
            if let micApp, let bundleID = micApp.bundleIdentifier {
                cameraAppName = micApp.localizedName
                cameraAppBundleID = bundleID
            } else if cameraAppBundleID == nil || !isRunning(cameraAppBundleID) {
                if let app = cameraApplicationCandidate() {
                    cameraAppName = app.localizedName
                    cameraAppBundleID = app.bundleIdentifier
                }
            }
        } else {
            cameraAppName = nil
            cameraAppBundleID = nil
        }
    }

    private func isRunning(_ bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == bundleID }
    }

    private func cameraApplicationCandidate() -> NSRunningApplication? {
        let own = Bundle.main.bundleIdentifier
        let front = NSWorkspace.shared.frontmostApplication
        if let front, front.bundleIdentifier != own, front.bundleIdentifier != "com.apple.finder" {
            return front
        }

        let tracker = PrivacyFrontmostTracker.shared
        if let bundleID = tracker.lastBundleID {
            if let running = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleID }) {
                return running
            }
        }

        return nil
    }

    private func micInputApplication() -> NSRunningApplication? {
        var size: UInt32 = 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyProcessObjectList,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectGetPropertyDataSize(
                AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr,
              size > 0 else { return nil }

        let count = Int(size) / MemoryLayout<AudioObjectID>.size
        var processes = [AudioObjectID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &processes) == noErr
        else { return nil }

        for process in processes {
            var isInput: UInt32 = 0
            var valueSize = UInt32(MemoryLayout<UInt32>.size)
            var inputAddress = AudioObjectPropertyAddress(
                mSelector: kAudioProcessPropertyIsRunningInput,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain)
            guard AudioObjectGetPropertyData(process, &inputAddress, 0, nil, &valueSize, &isInput) == noErr,
                  isInput != 0 else { continue }

            var pid = pid_t(0)
            var pidSize = UInt32(MemoryLayout<pid_t>.size)
            var pidAddress = AudioObjectPropertyAddress(
                mSelector: kAudioProcessPropertyPID,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain)
            if AudioObjectGetPropertyData(process, &pidAddress, 0, nil, &pidSize, &pid) == noErr,
               pid > 0,
               let app = NSRunningApplication(processIdentifier: pid) {
                return app
            }
        }
        return nil
    }

    private func fallbackMicApplication() -> NSRunningApplication? {
        let bundles = [
            "us.zoom.xos",
            "com.tinyspeck.slackmacgap", "com.apple.FaceTime", "com.hnc.Discord",
            "com.apple.QuickTimePlayerX", "com.loom.desktop", "com.apple.VoiceMemos",
            "net.whatsapp.WhatsApp", "com.cisco.webexmeetingsapp"
        ]
        return NSWorkspace.shared.runningApplications.first {
            guard let id = $0.bundleIdentifier else { return false }
            return bundles.contains(id)
        }
    }

    private func isCameraActive() -> Bool {
        var address = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))

        var size: UInt32 = 0
        guard CMIOObjectGetPropertyDataSize(CMIOObjectID(kCMIOObjectSystemObject), &address, 0, nil, &size) == noErr,
              size > 0 else { return false }

        let count = Int(size) / MemoryLayout<CMIOObjectID>.size
        var devices = [CMIOObjectID](repeating: 0, count: count)
        guard CMIOObjectGetPropertyData(CMIOObjectID(kCMIOObjectSystemObject), &address, 0, nil, size, &size, &devices) == noErr
        else { return false }

        for device in devices {
            var running: UInt32 = 0
            var valueSize = UInt32(MemoryLayout<UInt32>.size)
            var runningAddress = CMIOObjectPropertyAddress(
                mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
                mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
                mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))
            if CMIOObjectGetPropertyData(device, &runningAddress, 0, nil, valueSize, &valueSize, &running) == noErr,
               running != 0 {
                return true
            }
        }
        return false
    }

    private func screenCaptureApplication(mic: Bool, camera: Bool) -> NSRunningApplication? {
        let screenshotUI = "com.apple.screencaptureui"
        let recorders = [
            "com.loom.desktop",
            "tv.screenflow",
            "com.telestream.screenflow",
            "com.obsproject.obs-studio"
        ]
        let running = NSWorkspace.shared.runningApplications

        if let screenshots = running.first(where: { $0.bundleIdentifier == screenshotUI }) {
            return screenshots
        }
        guard mic || camera else { return nil }
        return running.first { recorders.contains($0.bundleIdentifier ?? "") }
    }
}
