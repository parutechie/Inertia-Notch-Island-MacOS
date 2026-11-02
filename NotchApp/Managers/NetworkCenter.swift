import CoreWLAN
import Foundation
import Network
import SwiftUI

struct NetworkStatusEvent {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
}

@MainActor
final class NetworkStatusCenter {
    var onEvent: ((NetworkStatusEvent) -> Void)?
    var onStateChange: ((NetworkState) -> Void)?

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "app.inertia.network")
    private var started = false
    private var lastConnected: Bool?
    private var lastInterface = ""
    private var lastSSID: String?
    private var lastWasExpensive = false
    private var eventTask: Task<Void, Never>?

    func start() {
        guard !started else { return }
        started = true
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in self?.handle(path) }
        }
        monitor.start(queue: queue)
    }

    private func handle(_ path: NWPath) {
        let connected = path.status == .satisfied
        let interface = path.availableInterfaces.first?.name ?? ""
        let wifi = CWWiFiClient.shared().interface()
        let ssid = wifi?.ssid()
        let wifiPowerOn = wifi?.powerOn() ?? false
        let expensive = path.isExpensive || (ssid?.localizedCaseInsensitiveContains("iphone") ?? false)

        let state = NetworkState(connected: connected, interface: interface)
        onStateChange?(state)

        if let lastConnected, lastConnected == connected {
            lastInterface = interface
            lastSSID = ssid
            lastWasExpensive = expensive
            return
        }

        let previousConnected = lastConnected
        lastConnected = connected
        lastInterface = interface
        lastSSID = ssid
        lastWasExpensive = expensive

        guard previousConnected != nil else { return }
        eventTask?.cancel()
        eventTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled, let self else { return }
            self.publish(connected: connected, previous: previousConnected == true,
                         interface: interface, ssid: ssid, expensive: expensive,
                         wifiPowerOn: wifiPowerOn)
        }
    }

    private func publish(connected: Bool, previous: Bool, interface: String, ssid: String?, expensive: Bool, wifiPowerOn: Bool) {
        if connected {
            if expensive {
                onEvent?(NetworkStatusEvent(title: "Personal Hotspot",
                                            subtitle: ssid.map { "Connected to \($0)" } ?? "Internet through your iPhone",
                                            icon: "personalhotspot",
                                            tint: .green))
            } else {
                let label = ssid ?? (interface.hasPrefix("en") ? "Wi-Fi" : "Network")
                onEvent?(NetworkStatusEvent(title: previous ? "Connected" : "Back online",
                                            subtitle: "\(label) is available",
                                            icon: "wifi",
                                            tint: .green))
            }
        } else {
            if wifiPowerOn, let ssid {
                onEvent?(NetworkStatusEvent(title: "No internet",
                                            subtitle: "\(ssid) has no internet access",
                                            icon: "wifi.exclamationmark",
                                            tint: .orange))
            } else if wifiPowerOn, !interface.isEmpty {
                onEvent?(NetworkStatusEvent(title: "Wi-Fi not connected",
                                            subtitle: "No network is selected",
                                            icon: "wifi.slash",
                                            tint: .orange))
            } else {
                onEvent?(NetworkStatusEvent(title: "You're offline",
                                            subtitle: "No internet connection",
                                            icon: "wifi.slash",
                                            tint: .orange))
            }
        }
    }
}
