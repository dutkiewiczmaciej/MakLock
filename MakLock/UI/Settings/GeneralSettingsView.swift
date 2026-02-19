import SwiftUI
import ServiceManagement

/// General settings tab: launch at login, idle auto-lock, sleep auto-lock.
struct GeneralSettingsView: View {
    @State private var settings = Defaults.shared.appSettings

    var body: some View {
        Form {
            Section {
                Toggle("Launch MakLock at login", isOn: $settings.launchAtLogin)

                Toggle("Lock apps when Mac sleeps", isOn: $settings.lockOnSleep)
            }

            Section {
                Toggle("Lock apps after idle timeout", isOn: $settings.lockOnIdle)

                if settings.lockOnIdle {
                    HStack {
                        Text("Timeout:")
                        Slider(
                            value: Binding(
                                get: { Double(settings.idleTimeoutMinutes) },
                                set: { settings.idleTimeoutMinutes = Int($0) }
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
        }
        .formStyle(.grouped)
        .padding()
        .onChange(of: settings.launchAtLogin) { _ in save() }
        .onChange(of: settings.lockOnSleep) { _ in save() }
        .onChange(of: settings.lockOnIdle) { _ in save() }
        .onChange(of: settings.idleTimeoutMinutes) { _ in save() }
    }

    private func save() {
        Defaults.shared.appSettings = settings

        // Start or stop idle monitoring based on toggle
        if settings.lockOnIdle {
            IdleMonitorService.shared.startMonitoring()
        } else {
            IdleMonitorService.shared.stopMonitoring()
        }

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
