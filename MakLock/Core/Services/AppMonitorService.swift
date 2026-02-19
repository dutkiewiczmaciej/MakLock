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
    /// These will NOT be re-locked until explicitly cleared (idle, sleep, manual).
    private var authenticatedApps: Set<String> = []

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

        NSLog("[MakLock] App monitor started")

        // Check already-running protected apps (e.g. after MakLock restart)
        // Delay briefly to let the UI finish loading
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.checkRunningApps()
        }
    }

    /// Scan currently running apps and trigger lock for any protected ones.
    private func checkRunningApps() {
        let workspace = NSWorkspace.shared
        for runningApp in workspace.runningApplications {
            handleAppEvent(runningApp)
        }
    }

    /// Stop monitoring.
    func stopMonitoring() {
        cancellables.removeAll()
        NSLog("[MakLock] App monitor stopped")
    }

    /// Mark an app as authenticated. It stays unlocked until session is cleared.
    func markAuthenticated(_ bundleIdentifier: String) {
        authenticatedApps.insert(bundleIdentifier)
        NSLog("[MakLock] App session authenticated: %@", bundleIdentifier)
    }

    /// Clear all authentication sessions (called on idle timeout, sleep, Watch out of range).
    func clearAllAuthentications() {
        authenticatedApps.removeAll()
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

        NSLog("[MakLock] Protected app detected: %@ (%@)", protectedApp.name, bundleID)
        detectedApp = protectedApp
        onProtectedAppDetected?(protectedApp)
    }
}
