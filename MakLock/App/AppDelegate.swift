import AppKit

/// Application delegate responsible for lifecycle and menu bar setup.
final class AppDelegate: NSObject, NSApplicationDelegate {
    let menuBarController = MenuBarController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarController.setup()

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
            OverlayWindowService.shared.show(for: app)
            self?.menuBarController.iconState = .locked
        }

        // Update icon when overlay is dismissed after successful auth
        OverlayWindowService.shared.onUnlocked = { [weak self] in
            self?.menuBarController.iconState = .active
        }

        // Start app monitoring
        AppMonitorService.shared.startMonitoring()

        // Wire up idle monitor → lock all protected apps
        IdleMonitorService.shared.onIdleTimeoutReached = { [weak self] in
            guard let self else { return }
            let apps = ProtectedAppsManager.shared.apps.filter(\.isEnabled)
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

        // Wire up sleep/wake → lock all protected apps on sleep
        SleepWakeService.shared.onSleep = { [weak self] in
            guard let self else { return }
            let apps = ProtectedAppsManager.shared.apps.filter(\.isEnabled)
            for app in apps {
                OverlayWindowService.shared.show(for: app)
            }
            if !apps.isEmpty {
                self.menuBarController.iconState = .locked
            }
        }

        // Start sleep/wake observer
        SleepWakeService.shared.startObserving()

        // Wire up Watch proximity → auto-unlock when Watch is in range
        WatchProximityService.shared.onWatchInRange = { [weak self] in
            guard OverlayWindowService.shared.isShowing else { return }
            OverlayWindowService.shared.hide()
            self?.menuBarController.iconState = .active
            NSLog("[MakLock] Auto-unlocked via Watch proximity")
        }

        // Wire up Watch proximity → lock when Watch leaves range
        WatchProximityService.shared.onWatchOutOfRange = { [weak self] in
            guard let self else { return }
            let apps = ProtectedAppsManager.shared.apps.filter(\.isEnabled)
            for app in apps {
                OverlayWindowService.shared.show(for: app)
            }
            if !apps.isEmpty {
                self.menuBarController.iconState = .locked
            }
        }

        // Start Watch proximity if enabled
        if Defaults.shared.appSettings.useWatchUnlock {
            WatchProximityService.shared.startScanning()
        }
    }
}
