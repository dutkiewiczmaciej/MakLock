import Foundation
import CoreBluetooth

/// Monitors Apple Watch BLE proximity for auto-unlock.
///
/// When the paired Watch moves out of range (RSSI below threshold),
/// the system triggers a lock. When it returns in range, auto-unlock fires.
final class WatchProximityService: NSObject, ObservableObject {
    static let shared = WatchProximityService()

    /// Callback when the Watch moves out of BLE range.
    var onWatchOutOfRange: (() -> Void)?

    /// Callback when the Watch returns to BLE range.
    var onWatchInRange: (() -> Void)?

    /// Whether the Watch is currently detected in range.
    @Published private(set) var isWatchInRange = false

    /// Whether BLE scanning is active.
    @Published private(set) var isScanning = false

    /// Current Bluetooth authorization status.
    @Published private(set) var bluetoothState: BluetoothState = .unknown

    enum BluetoothState {
        case unknown
        case poweredOn
        case poweredOff
        case unauthorized
        case unsupported
    }

    /// The paired Watch peripheral identifier (persisted).
    @Published var pairedWatchIdentifier: UUID? {
        didSet {
            if let id = pairedWatchIdentifier {
                UserDefaults.standard.set(id.uuidString, forKey: "MakLock.pairedWatchID")
            } else {
                UserDefaults.standard.removeObject(forKey: "MakLock.pairedWatchID")
            }
        }
    }

    /// RSSI threshold: values below this are considered "out of range".
    /// Default: -70 dBm (roughly 2-3 meters).
    var rssiThreshold: Int = -70

    private var centralManager: CBCentralManager?
    private var pairedPeripheral: CBPeripheral?
    private var rssiTimer: Timer?

    /// Number of consecutive out-of-range readings before triggering.
    private let outOfRangeCount = 3
    private var consecutiveOutOfRange = 0

    private override init() {
        super.init()

        // Restore paired Watch ID
        if let stored = UserDefaults.standard.string(forKey: "MakLock.pairedWatchID"),
           let uuid = UUID(uuidString: stored) {
            pairedWatchIdentifier = uuid
        }
    }

    /// Start BLE scanning for the paired Watch.
    func startScanning() {
        guard !isScanning else { return }
        centralManager = CBCentralManager(delegate: self, queue: nil)
        isScanning = true
        NSLog("[MakLock] Watch proximity scanning started")
    }

    /// Stop BLE scanning.
    func stopScanning() {
        rssiTimer?.invalidate()
        rssiTimer = nil
        centralManager?.stopScan()
        centralManager = nil
        pairedPeripheral = nil
        isScanning = false
        isWatchInRange = false
        consecutiveOutOfRange = 0
        NSLog("[MakLock] Watch proximity scanning stopped")
    }

    /// Unpair the current Watch.
    func unpair() {
        stopScanning()
        pairedWatchIdentifier = nil
        pairedPeripheral = nil
        NSLog("[MakLock] Watch unpaired")
    }

    // MARK: - Private

    private func startRSSIPolling() {
        rssiTimer?.invalidate()
        rssiTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.pairedPeripheral?.readRSSI()
        }
    }

    private func handleRSSI(_ rssi: Int) {
        if rssi < rssiThreshold {
            consecutiveOutOfRange += 1
            if consecutiveOutOfRange >= outOfRangeCount && isWatchInRange {
                isWatchInRange = false
                NSLog("[MakLock] Watch out of range (RSSI: %d, threshold: %d)", rssi, rssiThreshold)
                onWatchOutOfRange?()
            }
        } else {
            let wasOutOfRange = !isWatchInRange
            consecutiveOutOfRange = 0
            isWatchInRange = true
            if wasOutOfRange {
                NSLog("[MakLock] Watch in range (RSSI: %d)", rssi)
                onWatchInRange?()
            }
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension WatchProximityService: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn: bluetoothState = .poweredOn
        case .poweredOff: bluetoothState = .poweredOff
        case .unauthorized: bluetoothState = .unauthorized
        case .unsupported: bluetoothState = .unsupported
        default: bluetoothState = .unknown
        }

        guard central.state == .poweredOn else {
            if central.state == .unauthorized {
                NSLog("[MakLock] Bluetooth access not authorized — open System Settings → Privacy & Security → Bluetooth")
            }
            return
        }

        // If we have a paired Watch, try to reconnect
        if let watchID = pairedWatchIdentifier {
            let peripherals = central.retrievePeripherals(withIdentifiers: [watchID])
            if let peripheral = peripherals.first {
                pairedPeripheral = peripheral
                peripheral.delegate = self
                central.connect(peripheral)
                NSLog("[MakLock] Reconnecting to paired Watch: %@", watchID.uuidString)
                return
            }
        }

        // Otherwise scan for nearby devices
        central.scanForPeripherals(withServices: nil, options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: true
        ])
        NSLog("[MakLock] Scanning for Watch peripherals")
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        // Look for Apple Watch by name prefix
        guard let name = peripheral.name, name.contains("Apple Watch") else { return }

        // If no Watch is paired, pair with the first one found
        if pairedWatchIdentifier == nil {
            pairedWatchIdentifier = peripheral.identifier
            NSLog("[MakLock] Discovered Watch: %@ (ID: %@)", name, peripheral.identifier.uuidString)
        }

        guard peripheral.identifier == pairedWatchIdentifier else { return }

        central.stopScan()
        pairedPeripheral = peripheral
        peripheral.delegate = self
        central.connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        NSLog("[MakLock] Connected to Watch: %@", peripheral.identifier.uuidString)
        isWatchInRange = true
        consecutiveOutOfRange = 0
        startRSSIPolling()
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        NSLog("[MakLock] Watch disconnected")
        isWatchInRange = false
        rssiTimer?.invalidate()
        rssiTimer = nil
        onWatchOutOfRange?()

        // Try to reconnect
        central.connect(peripheral)
    }
}

// MARK: - CBPeripheralDelegate

extension WatchProximityService: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        guard error == nil else { return }
        handleRSSI(RSSI.intValue)
    }
}
