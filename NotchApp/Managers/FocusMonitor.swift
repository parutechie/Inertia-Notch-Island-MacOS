import AppKit
import Darwin
import notify
import ObjectiveC.runtime

@MainActor
final class SystemFocusMonitor {
    static let shared = SystemFocusMonitor()

    private let distributedNames = [
        "_NSDoNotDisturbEnabledNotification",
        "_NSDoNotDisturbDisabledNotification",
        "com.apple.notificationcenterui.dndprefs_changed",
        "com.apple.ncprefs.settings.changed",
        "com.apple.ncprefs.settings.accountschanged",
        "com.apple.focus.statusChanged",
        "com.apple.donotdisturb.statusChanged",
        "com.apple.menuextra.focusmode",
        "com.apple.controlcenter.focusmodes"
    ]

    private let darwinNames = [
        "com.apple.notificationcenter.dnd.state.changed",
        "com.apple.focus.assertion.state.changed",
        "com.apple.focus.status.changed"
    ]

    private var distributedObservers: [FocusNotificationRelay] = []
    private var darwinTokens: [Int32] = []
    private var dndService: AnyObject?
    private var dndListener: DNDStateUpdateListener?
    private var dndServiceClass: AnyClass?
    private var refreshTask: Task<Void, Never>?
    private var running = false
    private var focusActive = false
    private var lastPublished: (active: Bool, time: TimeInterval)?
    private var lastKnownState: Bool?
    private var lastRequestTime: TimeInterval = 0

    private init() {}

    func start() {
        guard !running else { return }
        running = true
        installDNDListener()
        installDistributedObservers()
        installDarwinObservers()
    }

    private var clientIdentifier: String {
        Bundle.main.bundleIdentifier ?? "bingiz.NotchApp"
    }

    private func installDistributedObservers() {
        let center = DistributedNotificationCenter.default()
        distributedObservers = distributedNames.map { name in
            let relay = FocusNotificationRelay(name: name) { [weak self] value in
                Task { @MainActor in self?.handleNotification(value) }
            }
            center.addObserver(relay, selector: #selector(FocusNotificationRelay.receive(_:)),
                               name: NSNotification.Name(name), object: nil,
                               suspensionBehavior: .deliverImmediately)
            return relay
        }
    }

    private func installDarwinObservers() {
        for name in darwinNames {
            var token: Int32 = 0
            let status = notify_register_dispatch(name, &token, DispatchQueue.main) { [weak self] _ in
                Task { @MainActor in self?.handleNotification(name) }
            }
            if status == NOTIFY_STATUS_OK { darwinTokens.append(token) }
        }
    }

    private func handleNotification(_ name: String) {
        guard running else { return }
        switch name {
        case "_NSDoNotDisturbEnabledNotification":
            refreshTask?.cancel()
            refreshTask = nil
            setState(true, announce: true, force: true)
        case "_NSDoNotDisturbDisabledNotification":
            refreshTask?.cancel()
            refreshTask = nil
            setState(false, announce: true, force: true)
        default:
            requestRefresh()
        }
    }

    private func requestRefresh() {
        let now = Date.timeIntervalSinceReferenceDate
        if refreshTask != nil, now - lastRequestTime < 0.15 { return }
        lastRequestTime = now
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            for delay in [Duration.milliseconds(80), .milliseconds(220), .milliseconds(520)] {
                try? await Task.sleep(for: delay)
                guard !Task.isCancelled else { return }
                await MainActor.run { self?.refreshKnownState() }
            }
            await MainActor.run { self?.refreshTask = nil }
        }
    }

    private func refreshKnownState() {
        guard running, let lastKnownState else { return }
        setState(lastKnownState, announce: true)
    }

    private func setState(_ active: Bool, announce: Bool, force: Bool = false) {
        let changed = focusActive != active
        focusActive = active
        guard announce, changed || force else { return }

        let now = Date.timeIntervalSinceReferenceDate
        if let lastPublished, lastPublished.active == active, now - lastPublished.time < 0.35 { return }
        lastPublished = (active, now)
        Store.shared.handleSystemFocusChange(active)
    }

    private func installDNDListener() {
        guard dndService == nil else { return }
        guard dlopen("/System/Library/PrivateFrameworks/DoNotDisturb.framework/DoNotDisturb", RTLD_NOW) != nil else { return }
        guard let serviceClass = NSClassFromString("DNDStateService") else { return }
        guard let service = makeService(serviceClass) else { return }

        let listener = DNDStateUpdateListener(clientIdentifier: clientIdentifier) { [weak self] active in
            Task { @MainActor in
                guard let self, self.running else { return }
                self.refreshTask?.cancel()
                self.refreshTask = nil
                self.lastKnownState = active
                self.setState(active, announce: true)
            }
        }

        var error: NSError?
        guard addListener(listener, to: service, serviceClass: serviceClass, error: &error) else { return }
        dndService = service
        dndListener = listener
        dndServiceClass = serviceClass
    }

    private func makeService(_ serviceClass: AnyClass) -> AnyObject? {
        let selector = NSSelectorFromString("_initWithClientIdentifier:")
        guard let instance = class_createInstance(serviceClass, 0) as AnyObject?,
              let implementation = class_getMethodImplementation(serviceClass, selector) else { return nil }
        typealias InitFunction = @convention(c) (AnyObject, Selector, NSString) -> AnyObject?
        return unsafeBitCast(implementation, to: InitFunction.self)(instance, selector, clientIdentifier as NSString)
    }

    private func addListener(_ listener: DNDStateUpdateListener, to service: AnyObject, serviceClass: AnyClass, error: AutoreleasingUnsafeMutablePointer<NSError?>?) -> Bool {
        let selector = NSSelectorFromString("addStateUpdateListener:error:")
        guard let implementation = class_getMethodImplementation(serviceClass, selector) else { return false }
        typealias AddFunction = @convention(c) (AnyObject, Selector, AnyObject, AutoreleasingUnsafeMutablePointer<NSError?>?) -> Bool
        return unsafeBitCast(implementation, to: AddFunction.self)(service, selector, listener, error)
    }
}

private final class FocusNotificationRelay: NSObject {
    private let name: String
    private let handler: (String) -> Void

    init(name: String, handler: @escaping (String) -> Void) {
        self.name = name
        self.handler = handler
        super.init()
    }

    @objc func receive(_ notification: Notification) {
        handler(name)
    }
}

private final class DNDStateUpdateListener: NSObject {
    private let identifier: String
    private let onUpdate: (Bool) -> Void

    init(clientIdentifier: String, onUpdate: @escaping (Bool) -> Void) {
        identifier = clientIdentifier
        self.onUpdate = onUpdate
        super.init()
    }

    @objc var clientIdentifier: String { identifier }

    @objc(remoteService:didReceiveDoNotDisturbStateUpdate:)
    func remoteService(_ service: AnyObject, didReceiveDoNotDisturbStateUpdate update: AnyObject) {
        handle(update)
    }

    @objc(stateService:didReceiveDoNotDisturbStateUpdate:)
    func stateService(_ service: AnyObject, didReceiveDoNotDisturbStateUpdate update: AnyObject) {
        handle(update)
    }

    @objc(remoteService:didReceiveStateUpdate:)
    func remoteService(_ service: AnyObject, didReceiveStateUpdate update: AnyObject) {
        handle(update)
    }

    private func handle(_ update: AnyObject) {
        autoreleasepool {
            if let object = update as? NSObject, let state = object.safeValue(forKey: "state"),
               let active = Self.isActive(in: state) {
                onUpdate(active)
                return
            }
            if let active = Self.isActive(in: update) { onUpdate(active) }
        }
    }

    static func isActive(in state: AnyObject) -> Bool? {
        guard let object = state as? NSObject else { return nil }
        for key in ["isActive", "active", "enabled", "isEnabled"] {
            if let value = object.boolValue(selector: key) ?? object.safeBool(forKey: key) { return value }
        }
        for key in ["activeModeIdentifier", "activeMode", "modeIdentifier", "currentMode"] {
            guard let value = object.objectValue(selector: key) ?? object.safeValue(forKey: key) else { continue }
            if let text = value as? String { return !text.isEmpty }
            return true
        }
        return nil
    }
}

private extension NSObject {
    func objectValue(selector name: String) -> AnyObject? {
        let selector = NSSelectorFromString(name)
        guard responds(to: selector), let implementation = class_getMethodImplementation(type(of: self), selector) else { return nil }
        typealias Getter = @convention(c) (AnyObject, Selector) -> AnyObject?
        return unsafeBitCast(implementation, to: Getter.self)(self, selector)
    }

    func boolValue(selector name: String) -> Bool? {
        let selector = NSSelectorFromString(name)
        guard responds(to: selector), let implementation = class_getMethodImplementation(type(of: self), selector) else { return nil }
        typealias Getter = @convention(c) (AnyObject, Selector) -> Bool
        return unsafeBitCast(implementation, to: Getter.self)(self, selector)
    }

    func safeValue(forKey key: String) -> AnyObject? {
        ObjCRuntimeSafety.value(forKey: key, from: self) as AnyObject?
    }

    func safeBool(forKey key: String) -> Bool? {
        if let value = ObjCRuntimeSafety.value(forKey: key, from: self) as? Bool { return value }
        if let value = ObjCRuntimeSafety.value(forKey: key, from: self) as? NSNumber { return value.boolValue }
        return nil
    }
}
