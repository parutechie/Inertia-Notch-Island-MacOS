import Foundation
import IOBluetooth
import Combine

final class BluetoothManager: ObservableObject {
    static let shared = BluetoothManager()
    @Published var connectedDevices: [(name: String, battery: Int?)] = []
    
    private init() {
        refresh()
    }
    
    func refresh() {
        var devices: [(name: String, battery: Int?)] = []
        if let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] {
            for device in paired {
                if device.isConnected() {
                    let name = device.name ?? "Unknown"
                    
                    var battery: Int? = nil
                    // Battery API may not be available in this SDK; skip
                    devices.append((name, battery))
                }
            }
        }
        connectedDevices = devices
    }
}
