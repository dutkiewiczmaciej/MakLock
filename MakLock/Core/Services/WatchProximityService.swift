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
/// Uses a hybrid approach:
/// - **Connection** to the paired Watch for reliable RSSI polling.
/// - **Background scanning** with `allowDuplicates` to detect Apple Continuity
///   "Nearby Info" packets, which reveal whether the Watch is on-wrist (unlocked).
///
/// When the paired Watch moves out of range or is taken off wrist,
/// the system triggers a lock. When it returns in range, auto-unlock fires.
final class WatchProximityService: NSObject, ObservableObject {
    static let shared = WatchProximityService()

    /// Callback when the Watch moves out of BLE range.
    var onWatchOutOfRange: (() -> Void)?

    /// Callback when the Watch returns to BLE range.
    var onWatchInRange: (() -> Void)?

    /// Whether the Watch is currently detected in range and unlocked (on wrist).
    @Published private(set) var isWatchInRange = false

    /// Whether the Watch is unlocked (on wrist) based on Continuity Nearby Info.
    /// `nil` means we haven't received lock state data yet (assume unlocked for backward compat).
    @Published private(set) var isWatchUnlocked: Bool?

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

    /// Number of consecutive out-of-range RSSI readings before triggering.
    private let outOfRangeCount = 3
    private var consecutiveOutOfRange = 0

    /// Number of consecutive "locked" Nearby Info readings before changing lock state.
    /// Prevents flapping from occasional noisy BLE packets.
    private let lockedReadingsRequired = 5
    private var consecutiveLockedReadings = 0

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
        isWatchUnlocked = nil
        consecutiveOutOfRange = 0
        consecutiveLockedReadings = 0
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
        // RSSI-only proximity detection.
        // Lock state (on-wrist) is checked separately in AppDelegate when deciding
        // whether to auto-unlock. Taking the Watch off does NOT re-lock already open apps —
        // it only prevents future auto-unlocks (requiring Touch ID instead).
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

    // MARK: - Nearby Info Parsing

    /// Parse Apple Continuity "Nearby Info" packet from BLE advertisement manufacturer data.
    /// Returns `true` if device is unlocked, `false` if locked, `nil` if not a Nearby Info packet.
    private func parseNearbyInfoLockState(from advertisementData: [String: Any]) -> Bool? {
        guard let mfgData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data,
              mfgData.count >= 6 else { return nil }

        // Check Apple Company ID (0x004C little-endian)
        guard mfgData[0] == 0x4C, mfgData[1] == 0x00 else { return nil }

        // Apple Continuity packets contain multiple TLV (Type-Length-Value) entries after the company ID.
        // We need to iterate through them to find Nearby Info (type 0x10).
        let payload = Array(mfgData.dropFirst(2))
        var offset = 0

        while offset + 1 < payload.count {
            let type = payload[offset]
            let length = Int(payload[offset + 1])
            let dataStart = offset + 2

            if type == 0x10, length >= 3, dataStart + 2 < payload.count {
                // Nearby Info found
                let dataFlags = payload[dataStart + 1]
                let unlocked = (dataFlags & 0x80) != 0
                return unlocked
            }

            offset = dataStart + length
        }

        return nil
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
            } else {
                watchLog("Paired Watch not found via retrievePeripherals, falling through to scan")
            }
        }

        // Always scan with allowDuplicates — picks up Nearby Info from ALL Apple devices
        // (the Watch may broadcast Nearby Info from a different BLE address than the connected one)
        central.scanForPeripherals(withServices: nil, options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: true
        ])
        watchLog("Scanning for BLE peripherals (allowDuplicates, Nearby Info detection)...")
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let peripheralName = peripheral.name
        let advName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let name = peripheralName ?? advName

        // --- Nearby Info detection: check lock state from Continuity advertisement ---
        if peripheral.identifier == pairedWatchIdentifier,
           let lockState = parseNearbyInfoLockState(from: advertisementData) {
            if lockState {
                // Unlocked → accept immediately (user put Watch back on)
                consecutiveLockedReadings = 0
                if isWatchUnlocked != true {
                    watchLog("Watch lock state changed: unlocked=true")
                    isWatchUnlocked = true
                }
            } else {
                // Locked → require multiple consecutive readings to avoid flapping
                consecutiveLockedReadings += 1
                if consecutiveLockedReadings >= lockedReadingsRequired && isWatchUnlocked != false {
                    watchLog("Watch lock state changed: unlocked=false (after \(consecutiveLockedReadings) readings)")
                    isWatchUnlocked = false
                }
            }
        }

        // --- Watch pairing and connection ---
        guard let name, name.localizedCaseInsensitiveContains("watch") else { return }

        // If no Watch is paired, pair with the first one found
        if pairedWatchIdentifier == nil {
            pairedWatchIdentifier = peripheral.identifier
            watchLog("Auto-paired with Watch: \(name) (ID: \(peripheral.identifier.uuidString))")
        }

        guard peripheral.identifier == pairedWatchIdentifier else { return }

        // Only connect if not already connected
        guard pairedPeripheral == nil else { return }

        pairedPeripheral = peripheral
        peripheral.delegate = self
        central.connect(peripheral)
        watchLog("Connecting to Watch: \(name)")
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        watchLog("Connected to Watch: \(peripheral.identifier.uuidString) (name: \(peripheral.name ?? "nil"))")
        // Don't set isWatchInRange here — let handleRSSI determine it
        // based on both RSSI threshold AND lock state from Nearby Info.
        startRSSIPolling()
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        watchLog("Failed to connect: \(peripheral.identifier.uuidString) error: \(error?.localizedDescription ?? "nil")")
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        watchLog("Watch disconnected (error: \(error?.localizedDescription ?? "none"))")
        isWatchInRange = false
        isWatchUnlocked = nil
        pairedPeripheral = nil
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
        handleRSSI(RSSI.intValue)
    }
}
