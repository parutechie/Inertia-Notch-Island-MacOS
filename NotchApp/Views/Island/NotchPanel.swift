import AppKit
import SwiftUI

struct NotchMetrics {
    let width: CGFloat
    let height: CGFloat
    /// Horizontal offset of the physical notch's centre from the screen centre.
    /// The panel is centred on the screen, so the shape must apply this offset
    /// to stay exactly under the cutout (and on displays where it is not centred).
    let centerOffset: CGFloat

    static var notchScreen: NSScreen {
        targetScreen(for: Store.shared.featureSettings.displayTarget)
    }
    static var screen: NSScreen { notchScreen }
    static func targetScreen(for target: DisplayTarget) -> NSScreen {
        switch target {
        case .builtIn:
            if let builtIn = NSScreen.screens.first(where: { $0.isBuiltIn }) { return builtIn }
        case .main:
            if let main = NSScreen.main { return main }
        }
        return NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main ?? NSScreen.screens[0]
    }
    static var current: NotchMetrics { metrics(for: notchScreen) }
    static func metrics(for screen: NSScreen) -> NotchMetrics {
        if screen.safeAreaInsets.top > 0,
           let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            let width = screen.frame.width - left.width - right.width
            let notchCenter = left.width + width / 2
            return .init(width: width,
                         height: screen.safeAreaInsets.top,
                         centerOffset: notchCenter - screen.frame.width / 2)
        }
        return .init(width: 150, height: 32, centerOffset: 0)
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber).map { CGDirectDisplayID($0.uint32Value) }
    }
    var isBuiltIn: Bool {
        displayID.map { CGDisplayIsBuiltin($0) != 0 } ?? false
    }
}

final class HitHostingView<Content: View>: NSHostingView<Content> {
    /// Horizontal offset of the physical notch from the hosting view's centre.
    var notchCenterOffset: CGFloat = 0

    // The panel never activates the app, so without this the first click on a button
    // is swallowed just to "focus" the window. That made controls feel dead.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let p = convert(point, from: superview)
        let s = Store.shared.hitSize
        let y = isFlipped ? p.y : bounds.height - p.y
        let center = bounds.midX + notchCenterOffset
        // FIX 5: reduced extra hit padding from 24pt to 4pt.
        let inside = abs(p.x - center) <= s.width / 2 + 4 && y <= s.height + 4
        return inside ? super.hitTest(point) : nil
    }
}

final class NotchPanel: NSPanel {
    // Wide enough for the open panel's full slider range (up to 720pt) plus shadow.
    static let size = CGSize(width: 800, height: 460)

    init() {
        super.init(contentRect: NSRect(origin: .zero, size: Self.size),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        acceptsMouseMovedEvents = true
        level = .mainMenu + 3
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        moveToTargetScreen()
    }

    func moveToTargetScreen() {
        let screen = NotchMetrics.notchScreen
        let frame = screen.frame
        let metrics = NotchMetrics.metrics(for: screen)
        setFrame(NSRect(x: frame.midX - Self.size.width / 2, y: frame.maxY - Self.size.height,
                        width: Self.size.width, height: Self.size.height), display: true)
        let host = HitHostingView(rootView: NotchView(notch: metrics))
        host.notchCenterOffset = metrics.centerOffset
        contentView = host
    }
    override var canBecomeKey: Bool { true }
}
