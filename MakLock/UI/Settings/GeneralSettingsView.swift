import SwiftUI
import ServiceManagement

/// General settings tab: launch at login, idle auto-lock, sleep auto-lock.
struct GeneralSettingsView: View {
    @State private var settings = Defaults.shared.appSettings
    @StateObject private var protectedAppsManager = ProtectedAppsManager.shared
    @State private var externalVolumes: [ExternalVolume] = []
    private let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    var body: some View {
        Form {
            Section {
                Toggle("Launch MakLock at login", isOn: $settings.launchAtLogin)
                    .toggleStyle(.goldSwitch)

                Toggle("Lock apps when Mac sleeps", isOn: $settings.lockOnSleep)
                    .toggleStyle(.goldSwitch)
            }

            Section {
                Toggle("Lock apps after idle timeout", isOn: $settings.lockOnIdle)
                    .toggleStyle(.goldSwitch)

                if settings.lockOnIdle {
                    HStack {
                        Text("Timeout:")
                        Slider(
                            value: Binding(
                                get: { Double(settings.idleTimeoutMinutes) },
                                set: { newValue in
                                    let minutes = Int(newValue)
                                    settings.idleTimeoutMinutes = minutes
                                    var current = Defaults.shared.appSettings
                                    current.idleTimeoutMinutes = minutes
                                    Defaults.shared.appSettings = current
                                    if settings.lockOnIdle {
                                        IdleMonitorService.shared.startMonitoring()
                                    }
                                }
                            ),
                            in: 1...30,
                            step: 1
                        )
                        Text("\(settings.idleTimeoutMinutes) min")
                            .frame(width: 50, alignment: .trailing)
                            .monospacedDigit()
                    }
                }
            }

            Section {
                HStack {
                    Text("Auto-close timeout:")
                    Slider(
                        value: Binding(
                            get: { Double(settings.inactiveCloseMinutes) },
                            set: { newValue in
                                let minutes = Int(newValue)
                                settings.inactiveCloseMinutes = minutes
                                var current = Defaults.shared.appSettings
                                current.inactiveCloseMinutes = minutes
                                Defaults.shared.appSettings = current
                            }
                        ),
                        in: 1...60,
                        step: 1
                    )
                    Text("\(settings.inactiveCloseMinutes) min")
                        .frame(width: 50, alignment: .trailing)
                        .monospacedDigit()
                }

                Text("Apps with the timer icon enabled will quit after this period of inactivity.")
                    .font(MakLockTypography.caption)
                    .foregroundColor(MakLockColors.textSecondary)
            }

            Section("External SSD Condition") {
                Toggle("Only lock selected app when selected SSD is disconnected", isOn: $settings.useExternalSSDCondition)
                    .toggleStyle(.goldSwitch)

                if settings.useExternalSSDCondition {
                    let enabledApps = protectedAppsManager.apps.filter(\.isEnabled)

                    if enabledApps.isEmpty {
                        Text("No enabled protected apps available. Add and enable apps in the Apps tab.")
                            .font(MakLockTypography.caption)
                            .foregroundColor(MakLockColors.textSecondary)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Protected apps")
                                .font(MakLockTypography.caption)
                                .foregroundColor(MakLockColors.textSecondary)

                            ForEach(enabledApps) { app in
                                Toggle(app.name, isOn: bindingForSsdConditionApp(app.bundleIdentifier))
                                    .toggleStyle(.goldSwitch)
                            }
                        }
                    }

                    Picker("External SSD", selection: selectedVolumeUUIDBinding) {
                        Text("Select SSD").tag("")
                        ForEach(externalVolumes) { volume in
                            Text(volume.name).tag(volume.uuid)
                        }
                    }

                    HStack {
                        Button("Refresh Drives") {
                            refreshExternalVolumes()
                        }

                        Spacer()

                        if let stateText = selectedVolumeConnectionStateText {
                            Text(stateText)
                                .font(MakLockTypography.caption)
                                .foregroundColor(
                                    stateText == "Connected" ? MakLockColors.success : MakLockColors.locked
                                )
                        }
                    }

                    Text("When enabled, selected apps are locked only if the selected SSD is not connected. Other protected apps continue using normal lock behavior.")
                        .font(MakLockTypography.caption)
                        .foregroundColor(MakLockColors.textSecondary)
                }
            }

            Section {
                Button("Check for Updates…") {
                    UpdateService.shared.updater.checkForUpdates()
                }

                HStack(spacing: 8) {
                    Text("MakLock \(version) (\(build))  ·  Made by MakMak")
                        .foregroundColor(MakLockColors.textSecondary)
                    Link(destination: URL(string: "https://github.com/dutkiewiczmaciej/MakLock")!) {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.up.right.square")
                            Text("GitHub")
                        }
                        .foregroundColor(MakLockColors.gold)
                    }
                }
                .font(MakLockTypography.caption)
            }
        }
        .formStyle(.grouped)
        .padding()
        .onChange(of: settings.launchAtLogin) { _ in save() }
        .onChange(of: settings.lockOnSleep) { _ in save() }
        .onChange(of: settings.lockOnIdle) { _ in save() }
        .onChange(of: settings.useExternalSSDCondition) { _ in save() }
        .onAppear {
            migrateLegacySsdConditionSelectionIfNeeded()
            refreshExternalVolumes()
        }
    }

    private func bindingForSsdConditionApp(_ bundleIdentifier: String) -> Binding<Bool> {
        Binding(
            get: {
                settings.effectiveSsdConditionAppBundleIdentifiers.contains(bundleIdentifier)
            },
            set: { isSelected in
                var selected = Set(settings.effectiveSsdConditionAppBundleIdentifiers)
                if isSelected {
                    selected.insert(bundleIdentifier)
                } else {
                    selected.remove(bundleIdentifier)
                }
                settings.ssdConditionAppBundleIdentifiers = Array(selected).sorted()
                settings.ssdConditionAppBundleIdentifier = nil
                save()
            }
        )
    }

    private var selectedVolumeUUIDBinding: Binding<String> {
        Binding(
            get: { settings.ssdConditionVolumeUUID ?? "" },
            set: { newValue in
                settings.ssdConditionVolumeUUID = newValue.isEmpty ? nil : newValue
                settings.ssdConditionVolumeName = externalVolumes.first(where: {
                    $0.uuid == newValue
                })?.name
                save()
            }
        )
    }

    private var selectedVolumeConnectionStateText: String? {
        guard let uuid = settings.ssdConditionVolumeUUID, !uuid.isEmpty else { return nil }
        return ExternalDriveService.shared.isVolumeConnected(uuid: uuid) ? "Connected" : "Disconnected"
    }

    private func refreshExternalVolumes() {
        externalVolumes = ExternalDriveService.shared.listMountedExternalVolumes()
    }

    private func migrateLegacySsdConditionSelectionIfNeeded() {
        guard settings.ssdConditionAppBundleIdentifiers.isEmpty,
              let legacyBundleID = settings.ssdConditionAppBundleIdentifier,
              !legacyBundleID.isEmpty else {
            return
        }

        settings.ssdConditionAppBundleIdentifiers = [legacyBundleID]
        settings.ssdConditionAppBundleIdentifier = nil
        save()
    }

    private func save() {
        Defaults.shared.appSettings = settings

        // Start or stop idle monitoring based on toggle
        if settings.lockOnIdle {
            IdleMonitorService.shared.startMonitoring()
        } else {
            IdleMonitorService.shared.stopMonitoring()
        }

        // Auto-close service is always running if any app has autoClose enabled
        // (started in AppDelegate, timeout changes take effect on next timer)

        // Register or unregister launch at login
        updateLaunchAtLogin(enabled: settings.launchAtLogin)
    }

    private func updateLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("[MakLock] Failed to update login item: %@", error.localizedDescription)
        }
    }
}
