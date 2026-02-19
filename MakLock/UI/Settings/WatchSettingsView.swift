import SwiftUI

/// Watch settings tab: Apple Watch proximity unlock.
struct WatchSettingsView: View {
    @State private var useWatchUnlock = false

    var body: some View {
        Form {
            Section {
                Toggle("Use Apple Watch to unlock", isOn: $useWatchUnlock)

                if useWatchUnlock {
                    HStack {
                        Image(systemName: "applewatch.radiowaves.left.and.right")
                            .font(.system(size: 24))
                            .foregroundColor(MakLockColors.info)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Searching for Apple Watch...")
                                .font(MakLockTypography.body)
                            Text("Make sure Bluetooth is on and your Watch is nearby.")
                                .font(MakLockTypography.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("How it works") {
                Text("When your Apple Watch is nearby, MakLock can automatically unlock protected apps without requiring Touch ID or a password.")
                    .font(MakLockTypography.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
