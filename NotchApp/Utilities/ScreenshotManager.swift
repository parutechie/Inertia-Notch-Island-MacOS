import AppKit
import SwiftUI

final class ScreenshotManager {
    static let shared = ScreenshotManager()
    private init() {}
    
    func captureArea() {
        let task = Process()
        task.launchPath = "/usr/sbin/screencapture"
        task.arguments = ["-i", "-c"]
        try? task.run()
    }
    
    func captureFullScreen() {
        let task = Process()
        task.launchPath = "/usr/sbin/screencapture"
        task.arguments = ["-c"]
        try? task.run()
    }
}
