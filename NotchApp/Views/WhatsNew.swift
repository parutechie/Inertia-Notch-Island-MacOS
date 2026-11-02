import AppKit
import SwiftUI

struct WhatsNewRelease {
    struct Feature: Identifiable {
        let id: String
        let title: String
        let description: String
    }

    let version: String
    let features: [Feature]

    static var current: WhatsNewRelease {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.1"
        return WhatsNewRelease(version: version, features: [
            Feature(id: "search", title: "Settings search",
                    description: "Find individual settings across every page instead of browsing one tab at a time."),
            Feature(id: "emoji", title: "Left and right emoji",
                    description: "Choose a character for each side of the island, or hide both while something is active."),
            Feature(id: "hud", title: "Live status controls",
                    description: "Set HUD timing, expand HUDs below the notch, and queue status updates in order."),
            Feature(id: "icons", title: "Source app icons",
                    description: "Music, meetings, microphone, camera, and screen sharing show the app behind the activity."),
            Feature(id: "focus", title: "Focus status",
                    description: "See when a Focus mode turns on or off with a short, quiet animation."),
            Feature(id: "volume", title: "Volume status",
                    description: "Hardware volume changes appear beside the notch with a level bar or percentage."),
            Feature(id: "privacy", title: "Privacy indicators",
                    description: "Microphone, camera, and screen-sharing activity shows the app using them."),
            Feature(id: "display", title: "Display control",
                    description: "Choose the built-in or main display, set the island width and hide it in fullscreen.")
        ])
    }
}

@MainActor
final class WhatsNewWindow: NSObject, NSWindowDelegate {
    static let shared = WhatsNewWindow()

    private var window: NSWindow?

    func showIfNeeded() {
        let defaults = UserDefaults.standard
        let release = WhatsNewRelease.current
        guard let last = defaults.string(forKey: "lastPresentedWhatsNewVersion") else {
            defaults.set(release.version, forKey: "lastPresentedWhatsNewVersion")
            if defaults.bool(forKey: "SUHasLaunchedBefore") { show() }
            return
        }
        guard release.version.compare(last, options: .numeric) == .orderedDescending else { return }
        defaults.set(release.version, forKey: "lastPresentedWhatsNewVersion")
        show()
    }

    func show() {
        if let window {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 520),
                              styleMask: [.titled, .closable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.delegate = self
        window.center()
        window.title = "What's New in Inertia"
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = .clear
        window.isOpaque = false
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.contentView = NSHostingView(rootView: WhatsNewView(release: .current) { [weak window] in
            window?.performClose(nil)
        })
        self.window = window
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        let closing = notification.object as? NSWindow
        let anotherVisible = NSApp.windows.contains {
            $0 !== closing && $0.isVisible && $0.level == .normal
        }
        if !anotherVisible { NSApp.setActivationPolicy(.accessory) }
    }
}

struct WhatsNewView: View {
    let release: WhatsNewRelease
    let dismiss: () -> Void

    var body: some View {
        ZStack {
            Rectangle().fill(.regularMaterial)
            VStack(spacing: 0) {
                VStack(spacing: 10) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 58, height: 58)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    Text("What's New in Inertia")
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                    Text("Version \(release.version)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 44)
                .padding(.bottom, 24)

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(release.features.enumerated()), id: \.element.id) { index, feature in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(feature.title).font(.system(size: 15, weight: .semibold))
                                Text(feature.description)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 13)
                            if index < release.features.count - 1 { Divider().opacity(0.35) }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .background(.black.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal, 36)

                Spacer(minLength: 20)
                Button("Continue", action: dismiss)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
                    .padding(.bottom, 26)
            }
        }
        .frame(width: 560, height: 520)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .ignoresSafeArea(.container, edges: .top)
    }
}
