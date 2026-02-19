import SwiftUI

/// Watch settings tab: Apple Watch proximity unlock with pairing and sensitivity.
struct WatchSettingsView: View {
    @ObservedObject private var watchService = WatchProximityService.shared
    @State private var settings = Defaults.shared.appSettings
    @State private var sensitivity: Double = 50

    var body: some View {
        Form {
            Section {
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

            if settings.useWatchUnlock {
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

                        Text("Make sure Bluetooth is on and your Watch is nearby.")
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
                                    // Map 0-100 slider to RSSI threshold: -90 (far) to -50 (close)
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
            // Map persisted RSSI threshold back to slider value
            let rssi = Double(watchService.rssiThreshold)
            sensitivity = ((rssi + 90) / 40.0) * 100
        }
    }

    private var sensitivityLabel: String {
        switch sensitivity {
        case 0..<30: return "Far"
        case 30..<70: return "Medium"
        default: return "Close"
        }
    }
}
