import Foundation
import SwiftUI
import AppKit
import IOKit.ps
import SystemConfiguration

// MARK: - Models

struct BatteryState: Equatable {
    var present = false
    var percent = 0
    var charging = false
    var plugged = false

    var symbol: String {
        if charging { return "battery.100.bolt" }
        switch percent {
        case 88...: return "battery.100"
        case 63...: return "battery.75"
        case 38...: return "battery.50"
        case 13...: return "battery.25"
        default:    return "battery.0"
        }
    }

    var tint: Color {
        if plugged { return .green }
        if percent <= 10 { return .red }
        if percent <= 20 { return .orange }
        return .white.opacity(0.8)
    }
}

struct NetworkState: Equatable {
    var connected = true
    var interface = ""
    var label: String {
        if !connected { return "Offline" }
        if interface.hasPrefix("en") { return "Wi-Fi" }
        if interface.hasPrefix("ppp") { return "Cellular" }
        return "Network"
    }
}

// MARK: - Monitoring

extension Store {
    func refreshSystemStatus() {
        let previousBattery = battery
        let currentBattery = Self.readBattery()
        battery = currentBattery?.present == true ? currentBattery : nil
        updateBatteryAlerts(previous: previousBattery, current: battery)

        let connected = Self.readNetworkConnected()
        let currentNetwork = NetworkState(connected: connected, interface: Self.readPrimaryInterface())
        if let was = networkWasConnected, was != connected, networkAlerts, !networkMonitoringActive {
            notify(AlertInfo(title: connected ? "Back online" : "You're offline",
                             subtitle: connected ? "\(currentNetwork.label) connected" : "No internet connection",
                             icon: connected ? "wifi" : "wifi.slash",
                             tint: connected ? .green : .orange,
                             snooze: false,
                             sticky: false,
                             until: Date().addingTimeInterval(4),
                             speak: false))
        }
        networkWasConnected = connected
        network = currentNetwork
    }

    private func updateBatteryAlerts(previous: BatteryState?, current: BatteryState?) {
        guard let current, current.present else {
            batteryWasPlugged = nil
            batteryWasCharging = false
            lowBatteryWarned.removeAll()
            batteryFullWarned = false
            return
        }

        if let was = batteryWasPlugged, was != current.plugged {
            if batteryAlerts {
                if current.plugged {
                    showLiveStatus(.charging(current.percent))
                } else {
                    notify(AlertInfo(title: "On battery",
                                     subtitle: "\(current.percent)% · unplugged",
                                     icon: "battery.50",
                                     tint: current.percent <= featureSettings.lowBatteryThreshold ? .orange : IslandTab.focus.tint,
                                     snooze: false,
                                     sticky: false,
                                     until: Date().addingTimeInterval(4),
                                     speak: false))
                }
            }
            lowBatteryWarned.removeAll()
            batteryFullWarned = false
        }
        batteryWasPlugged = current.plugged

        if current.plugged {
            lowBatteryWarned.removeAll()
            if batteryAlerts, batteryWasCharging, current.percent >= 100, !batteryFullWarned {
                batteryFullWarned = true
                notify(AlertInfo(title: "Battery full",
                                 subtitle: "You can unplug your Mac",
                                 icon: "battery.100.bolt",
                                 tint: .green,
                                 snooze: false,
                                 sticky: false,
                                 until: Date().addingTimeInterval(5),
                                 speak: false))
            }
        } else if batteryAlerts, let previous {
            let threshold = max(5, min(50, featureSettings.lowBatteryThreshold))
            let crossed = Array(Set([threshold, min(threshold, 10), min(threshold, 5)]))
                .filter { previous.percent > $0 && current.percent <= $0 && !lowBatteryWarned.contains($0) }
                .min()
            if let level = crossed {
                lowBatteryWarned.insert(level)
                notify(AlertInfo(title: "Low battery",
                                 subtitle: "\(current.percent)% remaining",
                                 icon: "battery.25",
                                 tint: .orange,
                                 snooze: false,
                                 sticky: true,
                                 until: Date().addingTimeInterval(10),
                                 speak: false))
            }
        }
        batteryWasCharging = current.charging
    }

    // MARK: Battery

    private static func readBattery() -> BatteryState? {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef]
        else { return nil }

        for source in sources {
            guard let raw = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue(),
                  let info = raw as? [String: Any],
                  (info[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType
            else { continue }

            var state = BatteryState()
            state.present = info[kIOPSIsPresentKey] as? Bool ?? true
            state.percent = info[kIOPSCurrentCapacityKey] as? Int ?? 0
            state.charging = info[kIOPSIsChargingKey] as? Bool ?? false
            let power = info[kIOPSPowerSourceStateKey] as? String
            state.plugged = power == kIOPSACPowerValue
            return state
        }
        return nil
    }

    // MARK: Network

    private static let reachability: SCNetworkReachability? = {
        SCNetworkReachabilityCreateWithName(nil, "apple.com")
    }()

    private static func readNetworkConnected() -> Bool {
        guard let reachability else { return true }
        var flags = SCNetworkReachabilityFlags()
        guard SCNetworkReachabilityGetFlags(reachability, &flags) else { return true }
        return flags.contains(.reachable) && !flags.contains(.connectionRequired)
    }

    private static func readPrimaryInterface() -> String {
        let store = SCDynamicStoreCreate(nil, "Inertia" as CFString, nil, nil)
        guard let store,
              let value = SCDynamicStoreCopyValue(store, "State:/Network/Global/IPv4" as CFString),
              let dict = value as? [String: Any]
        else { return "" }
        return dict["PrimaryInterface"] as? String ?? ""
    }
}
