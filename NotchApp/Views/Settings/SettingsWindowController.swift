import AppKit
import SwiftUI

final class SettingsWindowController: NSWindowController, NSWindowDelegate {

    static let shared = SettingsWindowController()

    private init() {
        let win = SettingsPanel()
        win.center()
        super.init(window: win)
        win.delegate = self
    }

    required init?(coder: NSCoder) { fatalError() }

    func show(page: SettingsPage? = nil) {
        if let p = page { Store.shared.settingsPage = p }

        if Store.shared.mode != .collapsed { Store.shared.mode = .collapsed }

        guard let win = window else { return }

        if !win.isVisible {
            var f = win.frame
            f.origin.y += 18
            win.setFrame(f, display: false)
        }

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.28
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            var target = win.frame
            target.origin.y -= 18
            win.animator().setFrame(target, display: true)
        }
    }

    func windowWillClose(_ notification: Notification) {
        Store.shared.refreshPermissions()
        NSApp.setActivationPolicy(.accessory)
    }
}

// UI-7: wider window (920×700), pure SwiftUI background (no vibrancy NSView).
private final class SettingsPanel: NSPanel {

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 920, height: 700),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        isOpaque          = false
        backgroundColor   = .clear
        isMovableByWindowBackground = false
        titlebarAppearsTransparent  = true
        titleVisibility   = .hidden
        titlebarSeparatorStyle = .none
        title             = "Inertia Settings"
        isReleasedWhenClosed = false
        hasShadow         = true
        toolbar           = nil
        // UI-7: sensible minimum for the floating sidebar + two-column cards.
        minSize           = NSSize(width: 820, height: 600)
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true

        // UI-7: plain hosting view — SettingsRootView draws its own near-black background.
        let hosting = NSHostingView(rootView: SettingsRootView())
        hosting.translatesAutoresizingMaskIntoConstraints = false
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor
        hosting.layer?.cornerRadius    = 26
        hosting.layer?.masksToBounds   = true

        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.clear.cgColor
        container.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: container.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        contentView = container
    }

    override var canBecomeKey:  Bool { true }
    override var canBecomeMain: Bool { true }
}
