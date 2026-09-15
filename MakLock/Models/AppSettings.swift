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

    /// Watch RSSI threshold for proximity detection.
    /// Default: -70 dBm (~2-3 meters). Higher (less negative) = stricter.
    var watchRssiThreshold: Int = -70

    /// Inactivity timeout (minutes) before auto-closing protected apps that have autoClose enabled.
    var inactiveCloseMinutes: Int = 15

    /// Launch MakLock at login.
    var launchAtLogin: Bool = false

    /// Whether the lock overlay should be fullscreen. If false, it will be a smaller modal window.
    var isFullScreenOverlay: Bool = false
}
