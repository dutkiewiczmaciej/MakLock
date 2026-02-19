import SwiftUI

/// SwiftUI content for the menu bar popover dropdown.
struct MenuBarView: View {
    let onToggleProtection: () -> Void
    let onSettingsClicked: () -> Void
    let onQuitClicked: () -> Void

    @State private var isProtectionEnabled = Defaults.shared.appSettings.isProtectionEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "lock.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(MakLockColors.gold)
                Text("MakLock")
                    .font(MakLockTypography.headline)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider()
                .padding(.horizontal, 8)

            // Status + Quick Toggle
            HStack {
                Circle()
                    .fill(isProtectionEnabled ? MakLockColors.success : MakLockColors.textSecondary)
                    .frame(width: 8, height: 8)
                Text(isProtectionEnabled ? "Protection Active" : "Protection Off")
                    .font(MakLockTypography.body)
                    .foregroundColor(.secondary)
                Spacer()
                Toggle("", isOn: $isProtectionEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .labelsHidden()
                    .onChange(of: isProtectionEnabled) { _ in
                        onToggleProtection()
                    }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            // Protected apps count
            let appCount = ProtectedAppsManager.shared.apps.filter(\.isEnabled).count
            HStack(spacing: 6) {
                Image(systemName: "app.badge.checkmark")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text("\(appCount) protected app\(appCount == 1 ? "" : "s")")
                    .font(MakLockTypography.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)

            Divider()
                .padding(.horizontal, 8)

            // Actions
            MenuBarButton(title: "Settings...", icon: "gearshape") {
                onSettingsClicked()
            }

            MenuBarButton(title: "About MakLock", icon: "info.circle") {
                showAboutWindow()
            }

            Divider()
                .padding(.horizontal, 8)

            MenuBarButton(title: "Quit MakLock", icon: "power") {
                onQuitClicked()
            }

            Spacer()
                .frame(height: 8)
        }
        .frame(width: 260)
    }

    private func showAboutWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 380),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "About MakLock"
        window.contentView = NSHostingView(rootView: AboutView())
        window.isReleasedWhenClosed = true
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Menu Bar Button

private struct MenuBarButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .frame(width: 16)
                Text(title)
                    .font(MakLockTypography.body)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? Color.white.opacity(0.1) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
