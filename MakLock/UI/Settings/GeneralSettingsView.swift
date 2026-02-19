import SwiftUI

/// General settings tab: launch at login, idle auto-lock, sleep auto-lock.
struct GeneralSettingsView: View {
    @State private var launchAtLogin = false
    @State private var lockOnSleep = true
    @State private var lockOnIdle = false
    @State private var idleTimeout = 5.0

    var body: some View {
        Form {
            Section {
                Toggle("Launch MakLock at login", isOn: $launchAtLogin)

                Toggle("Lock apps when Mac sleeps", isOn: $lockOnSleep)
            }

            Section {
                Toggle("Lock apps after idle timeout", isOn: $lockOnIdle)

                if lockOnIdle {
                    HStack {
                        Text("Timeout:")
                        Slider(value: $idleTimeout, in: 1...30, step: 1)
                        Text("\(Int(idleTimeout)) min")
                            .frame(width: 50, alignment: .trailing)
                            .monospacedDigit()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
