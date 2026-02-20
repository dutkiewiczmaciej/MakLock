import AppKit
import UserNotifications

/// Application delegate responsible for lifecycle and menu bar setup.
final class AppDelegate: NSObject, NSApplicationDelegate {
    let menuBarController = MenuBarController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarController.setup()

        // Request notification permission (for Watch unlock notifications)
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }

        // Show onboarding on first launch
        OnboardingWindowController.shared.showIfNeeded()

        // Initialize safety manager and wire up panic key
        SafetyManager.shared.onPanicKeyPressed = { [weak self] in
            OverlayWindowService.shared.dismissAll()
            self?.menuBarController.iconState = .idle
        }

        // Initialize settings window controller (listens for openSettings notification)
        _ = SettingsWindowController.shared

        // Wire up app monitor → overlay
        AppMonitorService.shared.onProtectedAppDetected = { [weak self] app in
            // Auto-unlock if Watch is in range AND unlocked (on wrist).
            // If Watch is nearby but locked/off wrist, fall through to Touch ID.
            let watch = WatchProximityService.shared
            let watchCanUnlock = Defaults.shared.appSettings.useWatchUnlock
                && watch.isWatchInRange
                && (watch.isWatchUnlocked ?? true)
            if watchCanUnlock {
                AppMonitorService.shared.markAuthenticated(app.bundleIdentifier)
                WatchUnlockToast.shared.show(for: app.bundleIdentifier)
                Self.sendWatchUnlockNotification(appName: app.name)
                return
            }
            OverlayWindowService.shared.show(for: app)
            self?.menuBarController.iconState = .locked
        }

        // Update icon when overlay is dismissed after successful auth
        OverlayWindowService.shared.onUnlocked = { [weak self] appName in
            self?.menuBarController.iconState = .active
            Self.sendUnlockNotification(appName: appName)
        }

        // Start Watch proximity BEFORE app monitoring so Watch has time to connect.
        // This prevents false overlay triggers on app restart.
        if Defaults.shared.appSettings.useWatchUnlock {
            WatchProximityService.shared.startScanning()
        }

        // Delay app monitoring slightly to give Watch time to connect on startup.
        // Without this, protected running apps would trigger overlays before
        // the Watch connection is established.
        let monitorDelay: TimeInterval = Defaults.shared.appSettings.useWatchUnlock ? 8.0 : 0
        DispatchQueue.main.asyncAfter(deadline: .now() + monitorDelay) {
            AppMonitorService.shared.startMonitoring()
        }

        // Wire up idle monitor → lock all running protected apps
        IdleMonitorService.shared.onIdleTimeoutReached = { [weak self] in
            guard let self else { return }
            AppMonitorService.shared.clearAllAuthentications()
            let runningBundleIDs = Set(NSWorkspace.shared.runningApplications.map(\.bundleIdentifier))
            let apps = ProtectedAppsManager.shared.apps.filter { $0.isEnabled && runningBundleIDs.contains($0.bundleIdentifier) }
            for app in apps {
                OverlayWindowService.shared.show(for: app)
            }
            if !apps.isEmpty {
                self.menuBarController.iconState = .locked
            }
        }

        // Start idle monitoring if enabled
        if Defaults.shared.appSettings.lockOnIdle {
            IdleMonitorService.shared.startMonitoring()
        }

        // Wire up sleep/wake → lock all running protected apps on sleep
        SleepWakeService.shared.onSleep = { [weak self] in
            guard let self else { return }
            AppMonitorService.shared.clearAllAuthentications()
            let runningBundleIDs = Set(NSWorkspace.shared.runningApplications.map(\.bundleIdentifier))
            let apps = ProtectedAppsManager.shared.apps.filter { $0.isEnabled && runningBundleIDs.contains($0.bundleIdentifier) }
            for app in apps {
                OverlayWindowService.shared.show(for: app)
            }
            if !apps.isEmpty {
                self.menuBarController.iconState = .locked
            }
        }

        // Start sleep/wake observer
        SleepWakeService.shared.startObserving()

        // Wire up Watch proximity → auto-unlock when Watch returns in range
        WatchProximityService.shared.onWatchInRange = { [weak self] in
            guard OverlayWindowService.shared.isShowing else { return }
            // Only auto-unlock if Watch is on wrist (unlocked)
            guard WatchProximityService.shared.isWatchUnlocked ?? true else { return }
            let lockedBundleID = OverlayWindowService.shared.currentBundleIdentifier
            let lockedAppName = OverlayWindowService.shared.currentAppName
            OverlayWindowService.shared.hide()
            WatchUnlockToast.shared.show(for: lockedBundleID)
            Self.sendWatchUnlockNotification(appName: lockedAppName ?? "app")
            self?.menuBarController.iconState = .active
        }

        // Wire up Watch proximity → lock when Watch leaves range
        WatchProximityService.shared.onWatchOutOfRange = { [weak self] in
            guard let self else { return }
            AppMonitorService.shared.clearAllAuthentications()
            // Only lock apps that are actually running — don't create overlays for closed apps
            let runningBundleIDs = Set(NSWorkspace.shared.runningApplications.map(\.bundleIdentifier))
            let apps = ProtectedAppsManager.shared.apps.filter { $0.isEnabled && runningBundleIDs.contains($0.bundleIdentifier) }
            for app in apps {
                OverlayWindowService.shared.show(for: app)
            }
            if !apps.isEmpty {
                self.menuBarController.iconState = .locked
            }
        }

    }

    /// Post a local notification when Watch auto-unlocks an app.
    static func sendWatchUnlockNotification(appName: String) {
        sendNotification(title: "Unlocked", body: "Apple Watch unlocked \(appName)")
    }

    /// Post a local notification when Touch ID or password unlocks an app.
    static func sendUnlockNotification(appName: String) {
        sendNotification(title: "Unlocked", body: "\(appName) unlocked with Touch ID")
    }

    private static func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = nil

        let request = UNNotificationRequest(
            identifier: "maklock-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
