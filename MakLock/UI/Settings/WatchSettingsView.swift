import SwiftUI

/// Watch settings tab: Apple Watch proximity unlock with pairing and sensitivity.
struct WatchSettingsView: View {
    @ObservedObject private var watchService = WatchProximityService.shared
    @State private var settings = Defaults.shared.appSettings
    @State private var sensitivity: Double = 50

    var body: some View {
        Form {
            // Bluetooth status
            Section {
                bluetoothStatusRow

                if watchService.bluetoothState == .poweredOn || watchService.bluetoothState == .unknown {
                    Toggle("Use Apple Watch to unlock", isOn: $settings.useWatchUnlock)
                        .onChange(of: settings.useWatchUnlock) { enabled in
                            Defaults.shared.appSettings = settings
                            if enabled {
                                watchService.startScanning()
                            } else {
                                watchService.stopScanning()
                            }
                        }
                }
            }

            if settings.useWatchUnlock && watchService.bluetoothState == .poweredOn {
                Section("Paired Watch") {
                    if let watchID = watchService.pairedWatchIdentifier {
                        HStack {
                            Image(systemName: "applewatch")
                                .font(.system(size: 24))
                                .foregroundColor(watchService.isWatchInRange ? MakLockColors.success : MakLockColors.textSecondary)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Apple Watch")
                                    .font(MakLockTypography.body)
                                Text(watchService.isWatchInRange ? "In range" : "Out of range")
                                    .font(MakLockTypography.caption)
                                    .foregroundColor(watchService.isWatchInRange ? MakLockColors.success : .secondary)
                            }

                            Spacer()

                            Button("Unpair") {
                                watchService.unpair()
                                settings.useWatchUnlock = false
                                Defaults.shared.appSettings = settings
                            }
                            .foregroundColor(MakLockColors.error)
                        }
                        .padding(.vertical, 4)

                        Text(watchID.uuidString)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    } else {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text("Searching for Apple Watch...")
                                .font(MakLockTypography.body)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)

                        Text("Make sure your Apple Watch is unlocked, on your wrist, and nearby.")
                            .font(MakLockTypography.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section("Sensitivity") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Range:")
                            Slider(value: $sensitivity, in: 0...100, step: 10)
                                .onChange(of: sensitivity) { value in
                                    let rssi = Int(-90 + (value / 100.0) * 40)
                                    watchService.rssiThreshold = rssi
                                }
                            Text(sensitivityLabel)
                                .frame(width: 50, alignment: .trailing)
                                .font(MakLockTypography.caption)
                                .monospacedDigit()
                        }

                        Text("Lower sensitivity means the Watch can be farther away. Higher sensitivity requires the Watch to be closer.")
                            .font(MakLockTypography.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section("How it works") {
                Text("When your Apple Watch is nearby, MakLock can automatically unlock protected apps without requiring Touch ID or a password. If the Watch moves out of range, apps will be locked again.")
                    .font(MakLockTypography.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            let rssi = Double(watchService.rssiThreshold)
            sensitivity = ((rssi + 90) / 40.0) * 100
        }
    }

    // MARK: - Bluetooth Status

    @ViewBuilder
    private var bluetoothStatusRow: some View {
        switch watchService.bluetoothState {
        case .poweredOn:
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(MakLockColors.success)
                Text("Bluetooth is on")
                    .font(MakLockTypography.body)
            }

        case .poweredOff:
            HStack(spacing: 8) {
                Image(systemName: "bluetooth")
                    .foregroundColor(MakLockColors.error)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bluetooth is off")
                        .font(MakLockTypography.body)
                    Text("Turn on Bluetooth in System Settings to use Apple Watch unlock.")
                        .font(MakLockTypography.caption)
                        .foregroundColor(.secondary)
                }
            }
            openSettingsButton(label: "Open Bluetooth Settings")

        case .unauthorized:
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(MakLockColors.locked)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bluetooth Permission Required")
                        .font(MakLockTypography.body)
                    Text("MakLock needs Bluetooth access to detect your Apple Watch. Grant permission in System Settings → Privacy & Security → Bluetooth.")
                        .font(MakLockTypography.caption)
                        .foregroundColor(.secondary)
                }
            }
            openSettingsButton(label: "Open Privacy Settings")

        case .unsupported:
            HStack(spacing: 8) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(MakLockColors.error)
                Text("Bluetooth is not supported on this Mac")
                    .font(MakLockTypography.body)
            }

        case .unknown:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Checking Bluetooth status...")
                    .font(MakLockTypography.body)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func openSettingsButton(label: String) -> some View {
        Button(label) {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth") {
                NSWorkspace.shared.open(url)
            }
        }
        .font(MakLockTypography.caption)
    }

    private var sensitivityLabel: String {
        switch sensitivity {
        case 0..<30: return "Far"
        case 30..<70: return "Medium"
        default: return "Close"
        }
    }
}
