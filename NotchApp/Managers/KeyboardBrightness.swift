import Foundation
import IOKit
import IOKit.hid
import Combine

final class KeyboardBrightnessManager: ObservableObject {
    static let shared = KeyboardBrightnessManager()
    @Published var brightness: Float = 0
    
    private init() {
        refresh()
    }
    
    func refresh() {
        brightness = getBrightness()
    }
    
    func getBrightness() -> Float {
        return min(max(brightness, 0), 1)
    }
    
    func setBrightness(_ value: Float) {
        brightness = min(max(value, 0), 1)
    }
}
