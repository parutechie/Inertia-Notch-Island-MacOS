import AppKit
import CoreGraphics

@MainActor
final class FullscreenMonitor {
    static let shared = FullscreenMonitor()

    var onChange: ((Bool) -> Void)?

    private var started = false
    private var task: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []
    private var lastValue = false

    private init() {}

    func start() {
        guard !started else { return }
        started = true
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        })
        observers.append(center.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        })
        task = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.5))
                guard !Task.isCancelled else { return }
                self?.refresh()
            }
        }
        refresh()
    }

    func refresh() {
        let value = Store.shared.featureSettings.hideNotchWhenFullscreen && isFullscreenVisible()
        guard value != lastValue else { return }
        lastValue = value
        onChange?(value)
    }

    private func isFullscreenVisible() -> Bool {
        let screen = Store.shared.featureSettings.displayTarget.screen ?? NotchMetrics.notchScreen
        let displayID = screen.displayID ?? CGMainDisplayID()
        let screenBounds = CGDisplayBounds(displayID).standardized
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let tolerance: CGFloat = 4
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
        return list?.contains { info in
            guard let pid = info[kCGWindowOwnerPID as String] as? pid_t, pid != ownPID,
                  (info[kCGWindowLayer as String] as? Int) == 0,
                  (info[kCGWindowAlpha as String] as? Double ?? 1) > 0.01,
                  let boundsInfo = info[kCGWindowBounds as String] as? [String: Any],
                  let x = boundsInfo["X"] as? Double,
                  let y = boundsInfo["Y"] as? Double,
                  let width = boundsInfo["Width"] as? Double,
                  let height = boundsInfo["Height"] as? Double else { return false }
            let frame = CGRect(x: x, y: y, width: width, height: height).standardized
            return frame.minX <= screenBounds.minX + tolerance &&
                frame.maxX >= screenBounds.maxX - tolerance &&
                frame.minY <= screenBounds.minY + tolerance &&
                frame.maxY >= screenBounds.maxY - tolerance
        } ?? false
    }
}
