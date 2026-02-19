import SwiftUI

/// Security settings tab: authentication method, backup password.
struct SecuritySettingsView: View {
    @State private var requireAuthOnLaunch = true
    @State private var hasBackupPassword = false

    var body: some View {
        Form {
            Section {
                Toggle("Require authentication on app launch", isOn: $requireAuthOnLaunch)
            }

            Section("Backup Password") {
                if hasBackupPassword {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(MakLockColors.success)
                        Text("Backup password is set")
                            .font(MakLockTypography.body)
                    }

                    Button("Change Password...") {
                        // Password setup will be connected in Task 10
                    }
                } else {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(MakLockColors.locked)
                        Text("No backup password set")
                            .font(MakLockTypography.body)
                    }

                    Button("Set Password...") {
                        // Password setup will be connected in Task 10
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            hasBackupPassword = KeychainManager.shared.hasPassword()
        }
    }
}
