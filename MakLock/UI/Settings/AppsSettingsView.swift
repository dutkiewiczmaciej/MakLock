import SwiftUI

/// Apps settings tab: manage the list of protected applications.
struct AppsSettingsView: View {
    @StateObject private var manager = ProtectedAppsManager.shared
    @State private var appPickerController = AppPickerWindowController()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Protected Applications")
                .font(MakLockTypography.title)

            if manager.apps.isEmpty {
                emptyState
            } else {
                appsList
            }

            Spacer()

            HStack {
                Spacer()
                PrimaryButton("Add App", icon: "plus") {
                    appPickerController.show()
                }
            }
        }
        .padding()
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "lock.open")
                .font(.system(size: 40))
                .foregroundColor(MakLockColors.textSecondary)
            Text("No protected apps yet")
                .font(MakLockTypography.headline)
                .foregroundColor(.secondary)
            Text("Add apps to protect them with Touch ID or password.")
                .font(MakLockTypography.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var appsList: some View {
        List {
            ForEach(manager.apps) { app in
                HStack(spacing: 12) {
                    AppIconView(bundleIdentifier: app.bundleIdentifier, size: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(app.name)
                            .font(MakLockTypography.headline)
                        Text(app.bundleIdentifier)
                            .font(MakLockTypography.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { app.isEnabled },
                        set: { _ in manager.toggleApp(app) }
                    ))
                    .toggleStyle(.switch)
                    .tint(MakLockColors.gold)

                    Button(action: { manager.removeApp(app) }) {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundColor(MakLockColors.error)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
            }
            .onDelete { indexSet in
                let appsToRemove = indexSet.map { manager.apps[$0] }
                appsToRemove.forEach { manager.removeApp($0) }
            }
        }
    }
}
