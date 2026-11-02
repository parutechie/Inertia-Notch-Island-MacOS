import Foundation
import AppKit
import IOKit
import IOKit.graphics
import Combine

private typealias DisplayServicesGetBrightnessFunction = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32

final class BrightnessManager: ObservableObject {
    static let shared = BrightnessManager()
    
    @Published private(set) var brightnessEventID = 0
    @Published private(set) var brightnessLevel: Double = 0
    
    private var manualInputObserver: NSObjectProtocol?
    private var lastPublishedLevel: Double?
    private var handledBrightnessInputGeneration = 0
    private let displayServicesGetBrightness = BrightnessManager.loadDisplayServicesGetBrightness()
    
    private init() {}
    
    func start() {
        guard manualInputObserver == nil else { return }
        ManualSystemControlMonitor.shared.start()
        
        let initialLevel = readBrightness() ?? 0
        brightnessLevel = initialLevel
        lastPublishedLevel = initialLevel
        
        manualInputObserver = NotificationCenter.default.addObserver(
            forName: .inertiaManualBrightnessInput,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.async {
                self?.handleManualBrightness()
            }
        }
    }
    
    private func handleManualBrightness() {
        guard let nextLevel = readBrightness() else { return }
        guard let last = lastPublishedLevel else {
            brightnessLevel = nextLevel
            lastPublishedLevel = nextLevel
            return
        }
        
        guard abs(nextLevel - last) >= 0.005 else { return }
        brightnessLevel = nextLevel
        lastPublishedLevel = nextLevel
        
        guard abs(nextLevel - last) >= 0.01,
              let generation = ManualSystemControlMonitor.shared.recentBrightnessInput(after: handledBrightnessInputGeneration) else { return }
        handledBrightnessInputGeneration = generation
        brightnessEventID += 1
    }
    
    private func readBrightness() -> Double? {
        for displayID in activeDisplayIDs() {
            if let brightness = readBrightness(for: displayID) {
                return brightness
            }
        }
        return nil
    }
    
    private func activeDisplayIDs() -> [CGDirectDisplayID] {
        var displayCount: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &displayCount) == .success, displayCount > 0 else {
            return [CGMainDisplayID()]
        }
        var displayIDs = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        guard CGGetActiveDisplayList(displayCount, &displayIDs, &displayCount) == .success else {
            return [CGMainDisplayID()]
        }
        return Array(displayIDs.prefix(Int(displayCount))).filter { $0 != 0 }
    }
    
    private func readBrightness(for displayID: CGDirectDisplayID) -> Double? {
        if let brightness = readDisplayServicesBrightness(for: displayID) {
            return brightness
        }
        return readIOKitBrightness(for: displayID)
    }
    
    private func readDisplayServicesBrightness(for displayID: CGDirectDisplayID) -> Double? {
        guard let displayServicesGetBrightness else { return nil }
        var value: Float = 0
        let result = displayServicesGetBrightness(displayID, &value)
        guard result == 0 else { return nil }
        return min(max(Double(value), 0), 1)
    }
    
    private func readIOKitBrightness(for displayID: CGDirectDisplayID) -> Double? {
        // CGDisplayIOServicePort is unavailable on modern macOS; rely on DisplayServices
        return nil
    }
    
    private static func loadDisplayServicesGetBrightness() -> DisplayServicesGetBrightnessFunction? {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY) else { return nil }
        guard let symbol = dlsym(handle, "DisplayServicesGetBrightness") else { return nil }
        return unsafeBitCast(symbol, to: DisplayServicesGetBrightnessFunction.self)
    }
}
