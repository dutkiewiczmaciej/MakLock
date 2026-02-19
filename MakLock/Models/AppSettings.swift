import Foundation

/// Persisted user preferences.
struct AppSettings: Codable {
    /// Whether MakLock protection is globally active.
    var isProtectionEnabled: Bool = true

    /// Lock apps when the Mac goes to sleep.
    var lockOnSleep: Bool = true

    /// Lock apps after idle timeout.
    var lockOnIdle: Bool = false

    /// Idle timeout in minutes before auto-lock triggers.
    var idleTimeoutMinutes: Int = 5

    /// Require authentication when a protected app is launched.
    var requireAuthOnLaunch: Bool = true

    /// Require authentication when switching to a protected app.
    var requireAuthOnActivate: Bool = false

    /// Use Apple Watch proximity for auto-unlock.
    var useWatchUnlock: Bool = false

    /// Launch MakLock at login.
    var launchAtLogin: Bool = false
}
