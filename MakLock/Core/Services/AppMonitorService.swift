import AppKit
import Combine

/// Monitors app launches and activations to detect when a protected app starts.
final class AppMonitorService: ObservableObject {
    static let shared = AppMonitorService()

    /// Published when a protected app is launched or activated.
    @Published var detectedApp: ProtectedApp?

    /// Callback invoked when a protected app is detected.
    var onProtectedAppDetected: ((ProtectedApp) -> Void)?

    private var cancellables = Set<AnyCancellable>()

    /// Apps that have been authenticated in the current session.
    /// Cleared when the app terminates, on idle timeout, sleep, or manual clear.
    private var authenticatedApps: Set<String> = []

    /// Bundle IDs that have a pending overlay prompt (not yet authenticated or cancelled).
    /// Prevents checkRunningApps from triggering duplicate prompts.
    private var pendingLockBundleIDs: Set<String> = []

    private init() {}

    /// Start monitoring app launches and activations.
    func startMonitoring() {
        let workspace = NSWorkspace.shared

        // Monitor app launches
        workspace.notificationCenter.publisher(for: NSWorkspace.didLaunchApplicationNotification)
            .compactMap { $0.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication }
            .sink { [weak self] app in
                self?.handleAppEvent(app)
            }
            .store(in: &cancellables)

        // Monitor app activations (switching to a running protected app)
        workspace.notificationCenter.publisher(for: NSWorkspace.didActivateApplicationNotification)
            .compactMap { $0.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication }
            .sink { [weak self] app in
                self?.handleAppEvent(app)
            }
            .store(in: &cancellables)

        // Monitor app terminations — clear auth when a protected app quits
        workspace.notificationCenter.publisher(for: NSWorkspace.didTerminateApplicationNotification)
            .compactMap { $0.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication }
            .sink { [weak self] app in
                guard let bundleID = app.bundleIdentifier else { return }
                self?.pendingLockBundleIDs.remove(bundleID)
                if self?.authenticatedApps.contains(bundleID) == true {
                    self?.authenticatedApps.remove(bundleID)
                    NSLog("[MakLock] App terminated, auth cleared: %@", bundleID)
                }
            }
            .store(in: &cancellables)

        // Monitor app deactivation — clear auth when user quits an app that stays
        // alive in the background (e.g. Messages closes windows on Cmd+Q but process
        // survives). Does NOT clear auth on Cmd+H (hide) or simple app switch.
        workspace.notificationCenter.publisher(for: NSWorkspace.didDeactivateApplicationNotification)
            .compactMap { $0.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication }
            .sink { [weak self] app in
                guard let bundleID = app.bundleIdentifier else { return }
                guard self?.authenticatedApps.contains(bundleID) == true else { return }

                // Delay to let window close animations finish
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    guard let self else { return }
                    if app.isTerminated {
                        self.authenticatedApps.remove(bundleID)
                        self.pendingLockBundleIDs.remove(bundleID)
                        NSLog("[MakLock] App terminated (deactivate check), auth cleared: %@", bundleID)
                    } else if !app.isHidden && !self.appHasWindows(app) {
                        self.authenticatedApps.remove(bundleID)
                        self.pendingLockBundleIDs.remove(bundleID)
                        NSLog("[MakLock] App quit (no windows), auth cleared: %@", bundleID)
                    }
                }
            }
            .store(in: &cancellables)

        NSLog("[MakLock] App monitor started")

        // Check already-running protected apps (e.g. after MakLock restart)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.checkRunningApps()
        }
    }

    /// Scan currently running apps and trigger lock for any protected ones.
    private func checkRunningApps() {
        let protectedList = Defaults.shared.protectedApps
        let settings = Defaults.shared.appSettings

        NSLog("[MakLock] checkRunningApps: %d protected, protection=%@",
              protectedList.count, settings.isProtectionEnabled ? "ON" : "OFF")

        guard settings.isProtectionEnabled else { return }

        let workspace = NSWorkspace.shared
        for runningApp in workspace.runningApplications {
            guard let bundleID = runningApp.bundleIdentifier else { continue }

            if let protectedApp = protectedList.first(where: {
                $0.bundleIdentifier == bundleID && $0.isEnabled
            }) {
                guard !authenticatedApps.contains(bundleID) else { continue }
                guard !pendingLockBundleIDs.contains(bundleID) else { continue }
                guard !OverlayWindowService.shared.isShowing else { continue }

                NSLog("[MakLock] Found running protected app: %@ (%@)", protectedApp.name, bundleID)
                detectedApp = protectedApp
                onProtectedAppDetected?(protectedApp)
                return // Only lock one at a time
            }
        }
    }

    /// Stop monitoring.
    func stopMonitoring() {
        cancellables.removeAll()
        NSLog("[MakLock] App monitor stopped")
    }

    /// Mark an app as authenticated. It stays unlocked until the app quits, idle, or sleep.
    func markAuthenticated(_ bundleIdentifier: String) {
        authenticatedApps.insert(bundleIdentifier)
        pendingLockBundleIDs.remove(bundleIdentifier)
        NSLog("[MakLock] App session authenticated: %@", bundleIdentifier)
    }

    /// Clear all authentication sessions (called on idle timeout, sleep, Watch out of range).
    func clearAllAuthentications() {
        authenticatedApps.removeAll()
        pendingLockBundleIDs.removeAll()
        NSLog("[MakLock] All app sessions cleared")
    }

    /// Clear authentication for a specific app.
    func clearAuthentication(for bundleIdentifier: String) {
        authenticatedApps.remove(bundleIdentifier)
    }

    /// Check if an app is currently authenticated.
    func isAuthenticated(_ bundleIdentifier: String) -> Bool {
        authenticatedApps.contains(bundleIdentifier)
    }

    /// Check if an app has any normal-level windows (layer 0).
    /// Returns false when an app was Cmd+Q'd but its process stayed alive.
    private func appHasWindows(_ app: NSRunningApplication) -> Bool {
        let pid = app.processIdentifier
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionAll], kCGNullWindowID
        ) as? [[String: Any]] else {
            return true // Assume yes if we can't query
        }
        return windowList.contains { info in
            guard let windowPID = info[kCGWindowOwnerPID as String] as? Int32,
                  let windowLayer = info[kCGWindowLayer as String] as? Int else {
                return false
            }
            // Layer 0 = normal window level (excludes menu extras, system UI)
            return windowPID == pid && windowLayer == 0
        }
    }

    private func handleAppEvent(_ runningApp: NSRunningApplication) {
        guard let bundleID = runningApp.bundleIdentifier else { return }

        // Skip blacklisted system apps
        guard !SafetyManager.isBlacklisted(bundleID) else { return }

        // Check if this app is in the protected list
        let protectedApps = Defaults.shared.protectedApps
        guard let protectedApp = protectedApps.first(where: {
            $0.bundleIdentifier == bundleID && $0.isEnabled
        }) else { return }

        // Check if global protection is enabled
        let settings = Defaults.shared.appSettings
        guard settings.isProtectionEnabled else { return }

        // Skip if app is already authenticated in this session
        guard !authenticatedApps.contains(bundleID) else { return }

        // Don't show overlay if one is already showing
        guard !OverlayWindowService.shared.isShowing else { return }

        // Don't trigger if a prompt is already pending for this app
        guard !pendingLockBundleIDs.contains(bundleID) else { return }

        NSLog("[MakLock] Protected app detected: %@ (%@)", protectedApp.name, bundleID)
        pendingLockBundleIDs.insert(bundleID)
        detectedApp = protectedApp
        onProtectedAppDetected?(protectedApp)
    }
}
