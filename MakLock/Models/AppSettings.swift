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

    /// Enable conditional locking based on external SSD presence.
    /// When enabled, MakLock only locks one selected protected app,
    /// and only when the selected external SSD is not connected.
    var useExternalSSDCondition: Bool = false

    /// Bundle identifier of the app controlled by the SSD condition.
    var ssdConditionAppBundleIdentifier: String?

    /// UUID of the external SSD volume used as the lock condition.
    var ssdConditionVolumeUUID: String?

    /// Last known display name of the selected SSD (for UI context).
    var ssdConditionVolumeName: String?

    enum CodingKeys: String, CodingKey {
        case isProtectionEnabled
        case lockOnSleep
        case lockOnIdle
        case idleTimeoutMinutes
        case requireAuthOnLaunch
        case requireAuthOnActivate
        case useWatchUnlock
        case watchRssiThreshold
        case inactiveCloseMinutes
        case launchAtLogin
        case useExternalSSDCondition
        case ssdConditionAppBundleIdentifier
        case ssdConditionVolumeUUID
        case ssdConditionVolumeName
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isProtectionEnabled = try container.decodeIfPresent(Bool.self, forKey: .isProtectionEnabled) ?? true
        lockOnSleep = try container.decodeIfPresent(Bool.self, forKey: .lockOnSleep) ?? true
        lockOnIdle = try container.decodeIfPresent(Bool.self, forKey: .lockOnIdle) ?? false
        idleTimeoutMinutes = try container.decodeIfPresent(Int.self, forKey: .idleTimeoutMinutes) ?? 5
        requireAuthOnLaunch = try container.decodeIfPresent(Bool.self, forKey: .requireAuthOnLaunch) ?? true
        requireAuthOnActivate = try container.decodeIfPresent(Bool.self, forKey: .requireAuthOnActivate) ?? false
        useWatchUnlock = try container.decodeIfPresent(Bool.self, forKey: .useWatchUnlock) ?? false
        watchRssiThreshold = try container.decodeIfPresent(Int.self, forKey: .watchRssiThreshold) ?? -70
        inactiveCloseMinutes = try container.decodeIfPresent(Int.self, forKey: .inactiveCloseMinutes) ?? 15
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        useExternalSSDCondition = try container.decodeIfPresent(Bool.self, forKey: .useExternalSSDCondition) ?? false
        ssdConditionAppBundleIdentifier = try container.decodeIfPresent(String.self, forKey: .ssdConditionAppBundleIdentifier)
        ssdConditionVolumeUUID = try container.decodeIfPresent(String.self, forKey: .ssdConditionVolumeUUID)
        ssdConditionVolumeName = try container.decodeIfPresent(String.self, forKey: .ssdConditionVolumeName)
    }
}
