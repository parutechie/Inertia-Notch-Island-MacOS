import Foundation
import CoreAudio
import Combine

final class AudioManager: ObservableObject {
    static let shared = AudioManager()
    @Published var outputVolume: Float = 0.5
    @Published var isMuted: Bool = false
    @Published var outputDeviceName: String = ""
    
    private init() {
        update()
    }
    
    func update() {
        if let vol = SystemOutputVolume.currentVolume() { outputVolume = Float(vol) }
        if let muted = SystemOutputVolume.isMuted() { isMuted = muted }
        outputDeviceName = currentOutputDeviceName()
    }
    
    private func currentOutputDeviceName() -> String {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                                mScope: kAudioObjectPropertyScopeGlobal,
                                                mElement: kAudioObjectPropertyElementMain)
        var deviceID = AudioDeviceID()
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        if AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID) != noErr { return "" }
        var name: CFString = "" as CFString
        var nameSize = UInt32(MemoryLayout<CFString>.size)
        var nameAddr = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyDeviceNameCFString,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        if AudioObjectGetPropertyData(deviceID, &nameAddr, 0, nil, &nameSize, &name) == noErr {
            return name as String
        }
        return ""
    }
}
