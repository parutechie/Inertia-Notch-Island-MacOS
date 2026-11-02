import SwiftUI
import Combine

@main
struct NotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @ObservedObject private var store = Store.shared

    var body: some Scene {
        // Menu bar removed - options moved to notch
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var panel: NotchPanel?
    private var bag = Set<AnyCancellable>()
    private var hiddenForFullscreen = false
    private var shortcutMonitor: Any?
    private var globalKeyMonitor: Any?
    // FIX 5: mouse-moved monitor for click-through when outside island.
    private var mouseMovedMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        panel = NotchPanel()
        panel?.orderFrontRegardless()
        Store.shared.startFeatures()
        BrightnessManager.shared.start()
        SystemControlCenter.shared.start()
        WhatsNewWindow.shared.showIfNeeded()

        Store.shared.featureSettings.$displayTarget
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.panel?.moveToTargetScreen()
                self?.updatePanelVisibility()
            }
            .store(in: &bag)

        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.panel?.moveToTargetScreen() }
            .store(in: &bag)

        Store.shared.$isFullscreenActive
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updatePanelVisibility() }
            .store(in: &bag)

        // TASK 2: start the intro after the panel is visible.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            Store.shared.startIntro()
        }

        // FIX 5: collapse on click outside — but do NOT consume the click so
        // the app underneath receives it.
        NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if Store.shared.showMenu {
                Store.shared.showMenu = false
            } else if Store.shared.mode == .open {
                // Only collapse if the click is outside the panel.
                if let self, !self.isInsideIsland(event) {
                    Store.shared.mode = .collapsed
                }
            }
            // TASK 3B: click inside the physical notch rect while hidden → restore
            if Store.shared.islandHidden, let self {
                let metrics = NotchMetrics.current
                let panelFrame = self.panel?.frame ?? .zero
                let centerX = panelFrame.midX + metrics.centerOffset
                let notchRect = NSRect(
                    x: centerX - metrics.width / 2,
                    y: panelFrame.maxY - metrics.height,
                    width: metrics.width,
                    height: metrics.height
                )
                let loc = event.locationInWindow  // screen coords for global monitor
                if notchRect.contains(loc) { self.showIsland() }
            }
        }

        Store.shared.$mode
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] m in
                if m == .open { self?.panel?.makeKey() }
                self?.updateIgnoresMouseEvents()
            }
            .store(in: &bag)

        // TASK 3B: react to islandHidden changes.
        Store.shared.$islandHidden
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hidden in
                guard let self else { return }
                if hidden {
                    self.panel?.orderOut(nil)
                } else {
                    self.panel?.orderFrontRegardless()
                }
            }
            .store(in: &bag)

        // FIX 5: global mouse-moved monitor so the panel becomes click-through
        // as soon as the cursor leaves the island shape.
        mouseMovedMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] _ in
            self?.updateIgnoresMouseEvents()
        }

        setupShortcuts()
    }

    // FIX 5: toggle ignoresMouseEvents based on current cursor position.
    private func updateIgnoresMouseEvents() {
        guard let panel else { return }
        let inside = isInsideIslandAtCurrentMouseLocation()
        // The panel should accept events when the cursor is inside the island
        // OR when the island is open (so the user can interact with it).
        let needsEvents = inside || Store.shared.mode == .open || Store.shared.mode == .alert
        panel.ignoresMouseEvents = !needsEvents
    }

    private func isInsideIsland(_ event: NSEvent) -> Bool {
        guard let panel else { return false }
        // Convert the event location (screen coords) to panel-relative coords.
        let screenPt = event.locationInWindow  // already in screen coords for global monitors
        return islandRect(in: panel).contains(screenPt)
    }

    private func isInsideIslandAtCurrentMouseLocation() -> Bool {
        guard let panel else { return false }
        let mousePt = NSEvent.mouseLocation
        return islandRect(in: panel).contains(mousePt)
    }

    /// Returns the island's rect in screen coordinates.
    private func islandRect(in panel: NotchPanel) -> NSRect {
        let s = Store.shared.hitSize
        let panelFrame = panel.frame
        let metrics = NotchMetrics.current
        let centerX = panelFrame.midX + metrics.centerOffset
        let islandX = centerX - s.width / 2 - 4
        let islandY = panelFrame.maxY - s.height - 4
        return NSRect(x: islandX, y: islandY, width: s.width + 8, height: s.height + 8)
    }

    private func setupShortcuts() {
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // TASK 3B: Ctrl+Opt+N toggles island hidden (unless keyboard is locked)
            if event.modifierFlags.contains([.control, .option])
                && event.charactersIgnoringModifiers?.lowercased() == "n"
                && !KeyboardLockManager.shared.isLocked {
                DispatchQueue.main.async { self?.toggleIslandHidden() }
                return
            }
            // TASK 2: Esc skips intro
            if event.keyCode == 53 && Store.shared.introActive {
                DispatchQueue.main.async { Store.shared.finishIntro() }
                return
            }
            guard event.keyCode == 53 else { return }
            DispatchQueue.main.async {
                if Store.shared.showMenu {
                    Store.shared.showMenu = false
                } else if Store.shared.mode == .open {
                    Store.shared.mode = .collapsed
                }
            }
        }

        shortcutMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // TASK 2: Esc skips the intro.
            if event.keyCode == 53 {
                if Store.shared.introActive {
                    Store.shared.finishIntro()
                    return nil
                }
                if Store.shared.showMenu {
                    Store.shared.showMenu = false
                    return nil
                }
                if Store.shared.mode == .open {
                    Store.shared.mode = .collapsed
                    return nil
                }
            }
            if event.modifierFlags.contains([.command, .shift]) && event.charactersIgnoringModifiers == "P" {
                return nil
            }
            if event.modifierFlags.contains([.command, .shift]) && event.charactersIgnoringModifiers == "4" {
                ScreenshotManager.shared.captureArea()
                return nil
            }
            return event
        }
    }

    // MARK: - TASK 3B: island hidden restore helpers

    func showIsland() {
        Store.shared.islandHidden = false
        hiddenForFullscreen = false
        panel?.orderFrontRegardless()
    }

    func toggleIslandHidden() {
        if Store.shared.islandHidden {
            showIsland()
        } else {
            Store.shared.mode = .collapsed
            Store.shared.islandHidden = true
            panel?.orderOut(nil)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // TASK 3B: reopening the app restores the island.
        if Store.shared.islandHidden { showIsland() }
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        // TASK 3A: safety — unlock keyboard before quitting.
        if KeyboardLockManager.shared.isLocked { KeyboardLockManager.shared.unlock() }
    }

    private func updatePanelVisibility() {
        guard let panel else { return }
        // TASK 3B: never show while explicitly hidden by the user.
        if Store.shared.islandHidden {
            panel.orderOut(nil)
            return
        }
        let hide = Store.shared.featureSettings.hideNotchWhenFullscreen && Store.shared.isFullscreenActive
        if hide, !hiddenForFullscreen {
            hiddenForFullscreen = true
            panel.orderOut(nil)
        } else if !hide, hiddenForFullscreen {
            hiddenForFullscreen = false
            panel.orderFrontRegardless()
        }
    }
}
