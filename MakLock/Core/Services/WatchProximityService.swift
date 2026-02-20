import AppKit
import CoreBluetooth
import os.log

private let logger = Logger(subsystem: "com.makmak.MakLock", category: "Watch")

private func watchLog(_ message: String) {
    logger.info("\(message, privacy: .public)")
    #if DEBUG
    let line = "[\(Date())] \(message)\n"
    let path = "/tmp/maklock-watch.log"
    if let handle = FileHandle(forWritingAtPath: path) {
        handle.seekToEndOfFile()
        handle.write(line.data(using: .utf8)!)
        handle.closeFile()
    } else {
        FileManager.default.createFile(atPath: path, contents: line.data(using: .utf8))
    }
    #endif
}

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

        // Restore RSSI threshold from settings
        rssiThreshold = Defaults.shared.appSettings.watchRssiThreshold
    }

    /// Start BLE scanning for the paired Watch.
    func startScanning() {
        guard !isScanning else { return }
        centralManager = CBCentralManager(delegate: self, queue: nil)
        isScanning = true
        watchLog("Watch proximity scanning started")
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
        watchLog("Watch proximity scanning stopped")
    }

    /// Unpair the current Watch.
    func unpair() {
        stopScanning()
        pairedWatchIdentifier = nil
        pairedPeripheral = nil
        watchLog("Watch unpaired")
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
                watchLog("Watch OUT OF RANGE (RSSI: \(rssi), threshold: \(rssiThreshold))")
                onWatchOutOfRange?()
            }
        } else {
            consecutiveOutOfRange = 0
            if !isWatchInRange {
                isWatchInRange = true
                watchLog("Watch IN RANGE (RSSI: \(rssi))")
                onWatchInRange?()
            }
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension WatchProximityService: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let oldState = bluetoothState
        switch central.state {
        case .poweredOn: bluetoothState = .poweredOn
        case .poweredOff: bluetoothState = .poweredOff
        case .unauthorized: bluetoothState = .unauthorized
        case .unsupported: bluetoothState = .unsupported
        default: bluetoothState = .unknown
        }

        watchLog("Bluetooth state: \(oldState) → \(bluetoothState)")

        // Reactivate app after Bluetooth permission dialog (menu bar app has no Dock icon)
        if oldState != .poweredOn && bluetoothState == .poweredOn {
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
            }
        }

        guard central.state == .poweredOn else {
            if central.state == .unauthorized {
                watchLog("Bluetooth access not authorized")
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
                watchLog("Reconnecting to paired Watch: \(watchID.uuidString)")
                return
            }
            watchLog("Paired Watch not found via retrievePeripherals, falling through to scan")
        }

        // Scan for nearby devices
        central.scanForPeripherals(withServices: nil, options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ])
        watchLog("Scanning for BLE peripherals...")
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        // Check both peripheral.name and advertisement local name
        let peripheralName = peripheral.name
        let advName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let name = peripheralName ?? advName

        // Log all named devices for debugging
        if let name {
            watchLog("BLE device: \"\(name)\" RSSI: \(RSSI) ID: \(peripheral.identifier.uuidString)")
        }

        // Look for Apple Watch by name (handles "Apple Watch", "Maciej's Apple Watch", etc.)
        guard let name, name.localizedCaseInsensitiveContains("watch") else { return }

        // If no Watch is paired, pair with the first one found
        if pairedWatchIdentifier == nil {
            pairedWatchIdentifier = peripheral.identifier
            watchLog("Auto-paired with Watch: \(name) (ID: \(peripheral.identifier.uuidString))")
        }

        guard peripheral.identifier == pairedWatchIdentifier else { return }

        central.stopScan()
        pairedPeripheral = peripheral
        peripheral.delegate = self
        central.connect(peripheral)
        watchLog("Connecting to Watch: \(name)")
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        watchLog("Connected to Watch: \(peripheral.identifier.uuidString) (name: \(peripheral.name ?? "nil"))")
        isWatchInRange = true
        consecutiveOutOfRange = 0
        startRSSIPolling()
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        watchLog("Failed to connect: \(peripheral.identifier.uuidString) error: \(error?.localizedDescription ?? "nil")")
        // Retry scan
        central.scanForPeripherals(withServices: nil, options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ])
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        watchLog("Watch disconnected (error: \(error?.localizedDescription ?? "none"))")
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
        guard error == nil else {
            watchLog("RSSI read error: \(error!.localizedDescription)")
            return
        }
        watchLog("RSSI: \(RSSI.intValue)")
        handleRSSI(RSSI.intValue)
    }
}
