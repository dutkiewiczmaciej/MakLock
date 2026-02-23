import Foundation

/// Manages authentication for accessing the menu bar popover.
///
/// Every click on the menu bar icon requires Touch ID (native system dialog
/// with macOS password fallback) or Apple Watch on wrist. No grace period —
/// each interaction is authenticated independently.
final class SettingsAuthService {
    static let shared = SettingsAuthService()

    private init() {}

    /// Whether Apple Watch can bypass the challenge (on wrist + in range).
    var canWatchBypass: Bool {
        let settings = Defaults.shared.appSettings
        let watch = WatchProximityService.shared
        return settings.useWatchUnlock
            && watch.isWatchInRange
            && (watch.isWatchUnlocked ?? true)
    }

    /// Whether no authentication method is available (safety valve).
    /// If the user has no Touch ID and no backup password, we can't gate settings
    /// or they'd be locked out permanently.
    private var hasNoAuthMethod: Bool {
        !AuthenticationService.shared.isTouchIDAvailable
            && !KeychainManager.shared.hasPassword()
    }

    /// Authenticate before opening the menu bar popover.
    ///
    /// - Watch on wrist → bypass with toast
    /// - No auth method → bypass silently (safety valve)
    /// - Otherwise → native Touch ID dialog with macOS password fallback
    func authenticate(completion: @escaping (Bool) -> Void) {
        if hasNoAuthMethod {
            completion(true)
            return
        }

        if canWatchBypass {
            completion(true)
            // Show toast after popover has opened
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                WatchUnlockToast.shared.show()
            }
            return
        }

        // Don't double-trigger if Touch ID is already in progress (e.g. app lock overlay)
        guard !AuthenticationService.shared.isAuthenticating else {
            completion(false)
            return
        }

        AuthenticationService.shared.authenticateWithSystemFallback(
            reason: "Access MakLock Settings"
        ) { result in
            switch result {
            case .success:
                completion(true)
            case .failure, .cancelled:
                completion(false)
            }
        }
    }
}
