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
    }

    /// Stop monitoring.
    func stopMonitoring() {
        cancellables.removeAll()
        NSLog("[MakLock] App monitor stopped")
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

        NSLog("[MakLock] Protected app detected: %@ (%@)", protectedApp.name, bundleID)
        detectedApp = protectedApp
        onProtectedAppDetected?(protectedApp)
    }
}
